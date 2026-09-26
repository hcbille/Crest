using CrestCore.Contracts;

namespace CrestCore.Application;

/// The cloud transport's state on this device, which the device store keeps
/// beside the session and never syncs: the engine's saved cursor, the server
/// fields of every uploaded record, and the rules for when a download must be
/// recovered with a full pull, when an account change waits for the person,
/// and when this device's copy overwrites the cloud's. The transport runs its
/// intents on its own thread; this takes its own lock, never the host's.
internal sealed class CloudTransportStore {
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
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(journalHoldsUploads);
        bool holdsUploads = intent is SettleCloudOverwrite && journalHoldsUploads();
        lock (gate) {
            switch (intent) {
                case OpenCloudTransport open:
                    Open(open);
                    break;
                case SaveCloudEngineState engine:
                    Save(record with { EngineState = engine.Serialization }, fields: null);
                    break;
                case RecordCloudFields fields:
                    Save(next: null, new CloudFieldWrite(Clearing: false, fields.Updated, fields.Removed));
                    break;
                case ForgetCloudZone zone:
                    Save(zone.Loss.RestoresLocalRecords ? record : record with { EngineState = null }, CloudFieldWrite.Cleared);
                    break;
                case ObserveCloudAccountChange change when change.Transition.AlwaysPauses && !record.AwaitsAccountDecision:
                    Save(record with { AwaitsAccountDecision = true }, fields: null);
                    break;
                case ObserveCloudAccountChange:
                    break;
                case BeginCloudMerge:
                    return Begin();
                case FinishCloudMerge finish:
                    Finish(finish);
                    break;
                case ResetCloudTransport reset:
                    needsRecovery = false;
                    Save(CloudTransportRecord.Initial(record.RecordSchema) with { OverwritesCloud = reset.OverwritesCloud },
                        CloudFieldWrite.Cleared);
                    break;
                case SettleCloudOverwrite when record.OverwritesCloud && !holdsUploads:
                    Save(record with { OverwritesCloud = false }, fields: null);
                    break;
                case SettleCloudOverwrite:
                    break;
                default:
                    throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "The transport does not handle this intent.");
            }
            return [Changed()];
        }
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
            Save(legacy, new CloudFieldWrite(Clearing: true, fields, []), DeviceAdoption.CloudTransport);
            adopted = true;
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
