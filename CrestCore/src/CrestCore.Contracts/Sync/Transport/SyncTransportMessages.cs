namespace CrestCore.Contracts;

#region Intents

/// An intent from the cloud transport about its own state on this device:
/// the engine's saved cursor, the last server fields of each record it
/// uploads over, whether a download must be recovered with a full pull,
/// whether an account change waits for the person's decision, and whether
/// this device's copy overwrites the cloud's. The device store keeps it
/// beside the session and never syncs it.
///
/// The transport sends one from its own thread, never the host's; the core
/// takes no lock the host's intents wait for. Each is on disk before it
/// returns, and a save that fails is `SaveFailed` and changes nothing. Its
/// answer carries `CloudTransportChanged` with the state it left, which
/// never reaches the host's state.
public abstract record CloudTransportIntent : Intent;

/// The transport is about to merge downloaded records into the session. The
/// device store notes first that a full pull must recover them, since the
/// engine may save a cursor past them even when the merge never completes.
/// Answers `CloudMergeBegan` naming the merge for `FinishCloudMerge`.
public sealed record BeginCloudMerge : CloudTransportIntent;

/// The merge `MergeId` ended, having taken its records when `Succeeded`. A
/// failed merge leaves a full pull required; a full snapshot taken with no
/// merge failing meanwhile recovers every earlier one. The full pull stays
/// required while another merge is under way. A merge this device never
/// began is `UnknownCloudMerge`.
public sealed record FinishCloudMerge(long MergeId, bool Succeeded, bool FullSnapshot) : CloudTransportIntent;

/// The cloud's zone of Crest's records is gone, as `Loss` says: every
/// record's server fields go with it, and so does the engine's saved state
/// unless the loss restores the zone from this device's records.
public sealed record ForgetCloudZone(CloudZoneLoss Loss) : CloudTransportIntent;

/// The iCloud account changed as `Transition` says. A change that always
/// pauses sync waits for the person's decision; a sign-in pauses only while
/// an earlier change still waits for one.
public sealed record ObserveCloudAccountChange(CloudAccountTransition Transition) : CloudTransportIntent;

/// The transport starts under `RecordSchema`, the newest record schema it
/// reads and writes. A cursor and server fields kept under an older schema
/// are left behind, so records the older build skipped are fetched again and
/// no upload builds on a server copy it could not read; everything else is
/// kept.
///
/// The first time, it carries the state an installed release kept in the
/// transport's own file into the device store: `Legacy` is that file exactly
/// as the host read it, or null when there is none. A pause older builds kept
/// for an ordinary record race is dropped. The state and the adoption's
/// marker are saved together, and the file is never changed, so a release
/// from before this one still reads it. Later, `Legacy` is ignored and the
/// host need not read the file: `CloudTransportState.IsAdopted` says so. A
/// file that does not read is `LegacyCloudStateUnreadable`, and nothing is
/// adopted.
[MessageLimit(128 * 1024 * 1024)]
public sealed record OpenCloudTransport(int RecordSchema, byte[]? Legacy) : CloudTransportIntent;

/// Keeps the server fields of `Updated`, replacing what was kept of each, and
/// forgets those of `Removed`.
[MessageLimit(64 * 1024 * 1024)]
public sealed record RecordCloudFields(IReadOnlyList<CloudRecordFields> Updated, IReadOnlyList<string> Removed)
    : CloudTransportIntent;

/// Starts the transport's state over, in one save: no saved cursor, no
/// server fields, no full pull and no account decision waiting. With
/// `OverwritesCloud`, this device's copy then overwrites the cloud's until
/// everything it staged has uploaded.
public sealed record ResetCloudTransport(bool OverwritesCloud) : CloudTransportIntent;

/// Keeps the sync engine's saved state, which it hands the transport to
/// resume from.
public sealed record SaveCloudEngineState(byte[] Serialization) : CloudTransportIntent;

/// Ends this device's overwrite of the cloud once the journal of the session
/// the core keeps in its file holds nothing waiting to upload, after every
/// stage queued before it settled. Refused with `NoStoredSession` or
/// `StoredSessionClosed` as a `CloudSyncIntent` is.
public sealed record SettleCloudOverwrite : CloudTransportIntent;

#endregion

#region Queries

/// The server fields the device store keeps of `RecordNames`.
public sealed record CloudFieldsOf(IReadOnlyList<string> RecordNames) : Query<CloudRecordFieldList>;

/// The fields the device store keeps of the records asked for; a record it
/// keeps none of is left out.
public sealed record CloudRecordFieldList(IReadOnlyList<CloudRecordFields> Records);

/// The cloud transport's state on this device.
public sealed record CloudTransport : Query<CloudTransportState>;

#endregion

#region Changes

/// A merge of downloaded records began as `MergeId`.
public sealed record CloudMergeBegan(long MergeId) : Change;

/// The cloud transport's state after the intent that answered it.
public sealed record CloudTransportChanged(CloudTransportState State) : Change;

#endregion

#region Rejections

/// The cloud transport state an installed release kept does not read. Nothing
/// was adopted.
public sealed record LegacyCloudStateUnreadable : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest couldn’t read the iCloud sync state an earlier version saved.";

    #endregion
}

/// No merge of downloaded records under way on this device is named `MergeId`.
public sealed record UnknownCloudMerge(long MergeId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest lost track of an iCloud download it was applying.";

    #endregion
}

#endregion

#region Models

/// The server's fields of one uploaded record, as the transport archived
/// them, and the record schema the server copy carries, which the archive
/// leaves out. The transport uploads over them, so a save targets the
/// server's version.
public sealed record CloudRecordFields(string RecordName, byte[] Fields, int? SchemaVersion);

/// The cloud transport's state on this device. `RequiresFullPull` holds while
/// a download may have advanced the cursor past content the session never
/// took, until a full snapshot is applied. `AwaitsAccountDecision` pauses
/// sync after the account changed until the person chooses which copy to
/// keep. `OverwritesCloud` holds after the person chose this device's copy,
/// until every record it staged has uploaded: meanwhile fetched content is
/// not merged and a record the server changed is uploaded again.
/// `EngineState` is the sync engine's own saved state, which only the
/// transport reads. `IsAdopted` tells whether the state an installed
/// release kept in its file was carried into the device store yet.
public sealed record CloudTransportState(
    bool RequiresFullPull,
    bool AwaitsAccountDecision,
    bool OverwritesCloud,
    byte[]? EngineState,
    bool IsAdopted);

#endregion
