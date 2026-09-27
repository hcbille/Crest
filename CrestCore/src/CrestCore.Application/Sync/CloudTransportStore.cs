using CrestCore.Contracts;

namespace CrestCore.Application;

/// The cloud transport's state on this device, which the device store keeps
/// beside the session and never syncs: the engine's saved cursor, the server
/// fields of every uploaded record, and the rules for when a download must be
/// recovered with a full pull, when an account change waits for the person,
/// and when this device's copy overwrites the cloud's. The transport runs its
/// intents on its own thread; this takes its own lock, never the host's.
internal sealed class CloudTransportStore : ICloudTransportIntentHandler<Func<bool>, IReadOnlyList<Change>> {
    #region Variables

    private readonly Lock gate = new();
    private readonly SessionStorage? storage;
    private readonly Device device;
    /// Each record's server fields, when no file keeps them.
    private readonly Dictionary<string, CloudRecordFields> memoryFields = new(StringComparer.Ordinal);
    /// The failures counted when each merge under way began.
    private readonly Dictionary<long, int> merges = [];

    private CloudTransportRecord record;
    private bool adopted;
    /// Sync was turned off before the installed release's state was adopted:
    /// the adoption starts it over unless an account decision waits.
    private bool resetsOnAdoption;
    /// A merge failed, or an earlier launch left one unrecovered, and no full
    /// snapshot has been taken since without another failing meanwhile.
    private bool needsRecovery;
    private int failedMerges;
    private long lastMerge;

    #endregion

    #region Constructors

    /// The state `storage` kept, or a transport that starts over in memory.
    /// A restore or a replaced session left the recovery marker: once the
    /// state was adopted, it starts over from a full pull now.
    public CloudTransportStore(SessionStorage? storage, Device device) {
        ArgumentNullException.ThrowIfNull(device);
        this.storage = storage;
        this.device = device;
        adopted = device.HasAdopted(DeviceAdoption.CloudTransport);
        record = storage?.CloudTransport ?? CloudTransportRecord.Initial(recordSchema: 0);
        needsRecovery = record.RequiresFullPull;
        if (!adopted || storage is not { CloudRecoveryRequested: true }) return;
        try {
            Recover();
        } catch (Rejected) {
            // The marker stays, so the next launch recovers instead.
        }
    }

    #endregion

    #region Actions - Intents

    /// Runs one transport intent, saving what it changed before it returns,
    /// and answers the state it left. `journalHoldsUploads` tells whether the
    /// stored session's journal still holds records waiting to upload, once
    /// every stage queued before settled. Throws `Rejected`.
    public IReadOnlyList<Change> Handle(CloudTransportIntent intent, Func<bool> journalHoldsUploads) {
        ArgumentNullException.ThrowIfNull(journalHoldsUploads);
        return intent.Dispatch(this, journalHoldsUploads);
    }

    public IReadOnlyList<Change> Handle(OpenCloudTransport open, Func<bool> journalHoldsUploads) => Saving(() => Open(open));

    public IReadOnlyList<Change> Handle(SaveCloudEngineState engine, Func<bool> journalHoldsUploads) =>
        Saving(() => Save(record with { EngineState = engine.Serialization }, fields: null));

    public IReadOnlyList<Change> Handle(RecordCloudFields fields, Func<bool> journalHoldsUploads) =>
        Saving(() => Save(next: null, new CloudFieldWrite(Clearing: false, fields.Updated, fields.Removed)));

    public IReadOnlyList<Change> Handle(ForgetCloudZone zone, Func<bool> journalHoldsUploads) =>
        Saving(() => Save(zone.Loss.RestoresLocalRecords ? record : record with { EngineState = null }, CloudFieldWrite.Cleared));

    public IReadOnlyList<Change> Handle(ObserveCloudAccountChange change, Func<bool> journalHoldsUploads) => Saving(() => {
        if (change.Transition.AlwaysPauses && !record.AwaitsAccountDecision) Save(record with { AwaitsAccountDecision = true }, fields: null);
    });

    public IReadOnlyList<Change> Handle(BeginCloudMerge begin, Func<bool> journalHoldsUploads) {
        lock (gate) return Begin();
    }

    public IReadOnlyList<Change> Handle(FinishCloudMerge finish, Func<bool> journalHoldsUploads) => Saving(() => Finish(finish));

    public IReadOnlyList<Change> Handle(ResetCloudTransport reset, Func<bool> journalHoldsUploads) => Saving(() => StartOver(reset.OverwritesCloud));

    /// The overwrite settles once no record waits to upload. The journal is
    /// read before the lock, since settling what was queued before waits.
    public IReadOnlyList<Change> Handle(SettleCloudOverwrite settle, Func<bool> journalHoldsUploads) {
        bool holdsUploads = journalHoldsUploads();
        return Saving(() => {
            if (record.OverwritesCloud && !holdsUploads) Save(record with { OverwritesCloud = false }, fields: null);
        });
    }

    /// Runs `work` holding the lock, and answers the state it left.
    private IReadOnlyList<Change> Saving(Action work) {
        lock (gate) {
            work();
            return [Changed()];
        }
    }

    /// Whether an account change waits for the person's decision.
    public bool AwaitsAccountDecision {
        get {
            lock (gate) return record.AwaitsAccountDecision;
        }
    }

    /// Starts the transport's state over, as `ResetCloudTransport` does.
    /// Throws `Rejected` with `SaveFailed`, keeping what was there.
    public void Reset(bool overwritesCloud) {
        lock (gate) StartOver(overwritesCloud);
    }

    /// Starts the transport's state over unless an account decision waits,
    /// as turning sync off does; before the installed release's state is
    /// adopted, the adoption does. Throws `Rejected` with `SaveFailed`.
    public void ResetUnlessAwaitingDecision() {
        lock (gate) {
            if (!adopted) resetsOnAdoption = true;
            else if (!record.AwaitsAccountDecision) StartOver(overwritesCloud: false);
        }
    }

    /// No cursor, no server fields, no full pull and no account decision
    /// waiting, in one save. The caller holds the lock.
    private void StartOver(bool overwritesCloud) {
        needsRecovery = false;
        Save(CloudTransportRecord.Initial(record.RecordSchema) with { OverwritesCloud = overwritesCloud }, CloudFieldWrite.Cleared);
    }

    /// Starts the transport under the schema it reads, adopting the installed
    /// release's file the first time. The caller holds the lock.
    private void Open(OpenCloudTransport open) {
        if (!adopted) {
            var (legacy, fields) = open.Legacy is { } bytes
                ? LegacyCloudTransportDocument.Read(bytes, open.RecordSchema)
                : (CloudTransportRecord.Initial(open.RecordSchema), []);
            bool recovers = storage is { CloudRecoveryRequested: true };
            if (recovers) (legacy, fields) = (legacy.Recovering(), []);
            if (resetsOnAdoption && !legacy.AwaitsAccountDecision)
                (legacy, fields) = (CloudTransportRecord.Initial(open.RecordSchema), []);
            Save(legacy, new CloudFieldWrite(Clearing: true, fields, []), DeviceAdoption.CloudTransport);
            adopted = true;
            resetsOnAdoption = false;
            device.NoteAdopted(DeviceAdoption.CloudTransport);
            needsRecovery = record.RequiresFullPull;
            if (recovers) storage!.ConsumeCloudRecovery();
            return;
        }
        if (record.RecordSchema < open.RecordSchema)
            Save(record with { RecordSchema = open.RecordSchema, EngineState = null }, CloudFieldWrite.Cleared);
    }

    /// Starts over from a full pull, keeping an account decision that waits,
    /// and removes the marker that asked for it. The caller holds the lock or
    /// is the constructor.
    private void Recover() {
        Save(record.Recovering(), CloudFieldWrite.Cleared);
        needsRecovery = true;
        storage!.ConsumeCloudRecovery();
    }

    /// Notes that a full pull must recover the merge that begins, before it
    /// begins, and answers its name. A note that cannot be saved counts as a
    /// failed merge. The caller holds the lock.
    private IReadOnlyList<Change> Begin() {
        try {
            Save(record with { RequiresFullPull = true }, fields: null);
        } catch (Rejected) {
            failedMerges++;
            needsRecovery = true;
            throw;
        }
        long id = ++lastMerge;
        merges[id] = failedMerges;
        return [new CloudMergeBegan(id), Changed()];
    }

    /// Ends a merge: a failed one leaves the full pull required; a full
    /// snapshot taken with no merge failing since it began recovers every
    /// earlier failure. The pull stays required while another merge is under
    /// way. The caller holds the lock.
    private void Finish(FinishCloudMerge finish) {
        if (!merges.Remove(finish.MergeId, out int failuresBefore)) throw new Rejected(new UnknownCloudMerge(finish.MergeId));
        if (!finish.Succeeded) {
            failedMerges++;
            needsRecovery = true;
            Save(record with { RequiresFullPull = true }, fields: null);
            return;
        }
        if (finish.FullSnapshot && failedMerges == failuresBefore) needsRecovery = false;
        try {
            Save(record with { RequiresFullPull = needsRecovery || merges.Count > 0 }, fields: null);
        } catch (Rejected) {
            needsRecovery = true;
            throw;
        }
    }

    /// Saves `next` and `fields` before keeping them; with `adoption`, its
    /// marker in the same transaction. Throws `Rejected` with `SaveFailed`,
    /// keeping what was there. The caller holds the lock.
    private void Save(CloudTransportRecord? next, CloudFieldWrite? fields, DeviceAdoption? adoption = null) {
        if (storage is { } target) {
            try {
                target.SaveCloudTransport(next, fields, adoption);
            } catch (StorageException error) {
                throw new Rejected(new SaveFailed(error.Reason));
            }
        } else if (fields is not null) {
            if (fields.Clearing) memoryFields.Clear();
            foreach (var name in fields.Removed) memoryFields.Remove(name);
            foreach (var kept in fields.Updated) memoryFields[kept.RecordName] = kept;
        }
        if (next is not null) record = next;
    }

    private CloudTransportChanged Changed() => new(record.Published(adopted));

    #endregion

    #region Actions - Queries

    public CloudTransportState Answer(CloudTransport query) {
        ArgumentNullException.ThrowIfNull(query);
        lock (gate) return record.Published(adopted);
    }

    /// The server fields kept of the records asked for. Throws `Rejected`
    /// with `StorageUnreadable` when the file cannot be read.
    public CloudRecordFieldList Answer(CloudFieldsOf query) {
        ArgumentNullException.ThrowIfNull(query);
        lock (gate) {
            if (storage is not { } source)
                return new([.. query.RecordNames.Where(memoryFields.ContainsKey).Select(name => memoryFields[name])]);
            try {
                return new(source.CloudFields(query.RecordNames));
            } catch (StorageException error) {
                throw new Rejected(new StorageUnreadable(error.Reason));
            }
        }
    }

    #endregion
}
