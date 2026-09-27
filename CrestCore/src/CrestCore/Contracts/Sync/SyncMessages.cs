namespace CrestCore.Contracts;

#region Intents

/// An intent from the cloud transport about the session the core keeps in its
/// file, which alone syncs. Refused with `NoStoredSession` when the core keeps
/// no file, its file holds no session, or that session is not open yet, which
/// the transport never meets since it starts after `OpenWorkspace`; and with
/// `StoredSessionClosed` once that session closed. Each is saved with its
/// journal before it returns; a save that fails is `SaveFailed` and changes
/// nothing. A locked Space never refuses one: sync converges in the background.
///
/// The transport sends one from its own thread, never the host's: the core
/// computes it there, outside its lock, and takes the lock only to commit it.
/// What it changed reaches the host through the next drain, as one batch after
/// the wake, never in its answer, which carries only the intent's receipts.
///
/// Records the core cannot take are `InvalidSyncRecords`, and a journal that
/// cannot record the result is `SyncStagingRefused`; either changes nothing.
public abstract record CloudSyncIntent : Intent;

/// The cloud saved `Records`. Each that the journal still holds at exactly the
/// version the cloud saved no longer waits to upload; one the journal wrote
/// again since, or no longer holds, is left as it is. The journal is saved
/// before this returns and publishes `SyncJournalChanged`; the session does not
/// change.
public sealed record AcknowledgeUploads(IReadOnlyList<UploadedRecord> Records) : CloudSyncIntent;

/// A record the cloud saved, at the version it saved.
public sealed record UploadedRecord(SyncRecordReference Record, SyncVersion Version);

/// Merges every record the cloud holds, as `MergeSyncRecords` merges a batch,
/// when the transport pulls the whole zone to recover. The snapshot is refused
/// whole with `InvalidSyncRecords` naming `UnreadablePayload` when any of its
/// records is one this build cannot read, so an incomplete snapshot never
/// decides what this device holds.
[MessageLimit(64 * 1024 * 1024)]
public sealed record MergeCloudSnapshot(IReadOnlyList<SyncRecord> Records) : CloudSyncIntent;

/// Merges records the cloud sent into the session and its journal. The
/// session's edits are staged first; each record the journal holds already
/// resolves against the one that arrived, field by field where the fields carry
/// their own clocks; the session is rebuilt from the reconciled records,
/// repaired, swept for retention and staged again. A Space tombstone for an
/// explicit deletion begins deleting that Space on this device. A record the
/// journal holds in another Space is refused.
[MessageLimit(64 * 1024 * 1024)]
public sealed record MergeSyncRecords(IReadOnlyList<SyncRecord> Records) : CloudSyncIntent;

/// Prepares the journal to overwrite the cloud with this device's session, as
/// the person chose: each record the cloud holds is superseded by one written
/// above it, and every record waits to upload. The session does not change.
[MessageLimit(64 * 1024 * 1024)]
public sealed record OverwriteCloud(IReadOnlyList<SyncRecord> Records) : CloudSyncIntent;

/// Replaces the session with the cloud's records, as `ReplaceWithCloudRecords`
/// does, while it is still the disposable seed a first launch made. It changes
/// nothing once the seed is gone.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ReplaceSeedWithCloudRecords(IReadOnlyList<SyncRecord> Records) : CloudSyncIntent;

/// Replaces the session's synced content and its journal with the cloud's
/// records, as the person chose. Nothing waits to upload afterwards, and an
/// empty cloud leaves one new ordinary Space. What only this device keeps, its
/// app preferences and the Space deletions under way, stays.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ReplaceWithCloudRecords(IReadOnlyList<SyncRecord> Records) : CloudSyncIntent;

#endregion

#region Queries

/// How the stored session's journal compares with `Cloud`, every record the
/// cloud holds, which the transport asks before it syncs with an account it has
/// not synced with yet. Refused as a `CloudSyncIntent` is, with
/// `NoStoredSession` or `StoredSessionClosed`.
[MessageLimit(64 * 1024 * 1024)]
public sealed record CloudComparison(IReadOnlyList<SyncRecord> Cloud) : Query<CloudContentComparison>;

/// Which records of the stored session's journal wait to upload. Refused as a
/// `CloudSyncIntent` is, with `NoStoredSession` or `StoredSessionClosed`.
public sealed record PendingUploads : Query<PendingUploadList>;

/// The records that wait to upload, in the order of their record names. None
/// while the stored session is the disposable seed a first launch made, which
/// never syncs.
public sealed record PendingUploadList(IReadOnlyList<SyncRecordReference> Records);

/// The journal's current record for each of `Records`, as the cloud transport
/// uploads it. Refused as a `CloudSyncIntent` is, with `NoStoredSession` or
/// `StoredSessionClosed`.
public sealed record RecordsToUpload(IReadOnlyList<SyncRecordReference> Records) : Query<UploadBatch>;

/// What the journal holds of the records a transport asked for: `Records`, each
/// one it holds and sends, in the order asked, and `Gone`, each one it no
/// longer holds, whose pending save the transport drops. A record it holds but
/// does not send, since no client would read it, is in neither, so its save
/// stays pending. While the stored session is the disposable seed a first
/// launch made, which never syncs, every record is gone.
public sealed record UploadBatch(IReadOnlyList<SyncRecord> Records, IReadOnlyList<SyncRecordReference> Gone);

#endregion

#region Changes

/// The session's sync journal changed: the core staged the session's accepted
/// edits, took a merge or an acknowledged upload, or attached the journal it
/// loaded. When the session keeps a file the journal is on disk with them. The
/// journal holds `Records` records, and `PendingRecords` of them wait to
/// upload. The cloud transport schedules an upload when it hears this.
public sealed record SyncJournalChanged(Guid WorkspaceId, int PendingRecords, int Records) : Change;

/// The receipt of a cloud intent that left records out: `Unreadable` records
/// no client of this build's schema reads, and `FromNewerBuild` records a
/// newer build wrote for a schema this build does not know. Nothing else about
/// the intent changes; the transport tells the person, and that updating Crest
/// on this device reads the second kind.
public sealed record SyncRecordsSkipped(int Unreadable, int FromNewerBuild) : Change;

/// The core could not stage the session's accepted edits for sync. The journal
/// is as it was; the next staged edit reports `SyncJournalChanged`.
public sealed record SyncStagingFailed(Guid WorkspaceId, SyncStagingFailure Reason) : Change;

#endregion

#region Rejections

/// The core cannot take the records the cloud sent, for the reason `Flaw`
/// names, about the record, tab, Space or profile `Subject` names when there is
/// one. Nothing changed.
public sealed record InvalidSyncRecords(SyncRecordFlaw Flaw, Guid? Subject) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest couldn’t apply the latest changes from iCloud.";

    #endregion
}

/// A command whose sync journal is saved with it could not stage that journal,
/// so the core refused the command and changed nothing.
public sealed record SyncStagingRefused(SyncStagingFailure Reason) : Rejection;

#endregion

#region Models

/// Whether this device's journal and the cloud hold the same content: the same
/// records, each in the same Space with an equivalent payload or tombstone.
/// Versions do not count, and of two cloud records with one identity the later
/// counts. `DeviceRecords` and `CloudRecords` count every record each holds,
/// tombstones included; `DeviceSpaces` and `CloudSpaces` count the Spaces each
/// keeps. A device whose session is the disposable seed a first launch made
/// holds nothing.
public sealed record CloudContentComparison(bool Matches, int DeviceRecords, int CloudRecords, int DeviceSpaces, int CloudSpaces);

/// One synced record as the transport carries it: its kind and identity, the
/// Space it belongs to, the version that wrote it, the oldest CloudKit schema
/// whose clients read it whole, and its body, which is its tombstone when
/// `IsTombstone` and its payload otherwise. The body is the CloudKit field as
/// the cloud stores it, with dates in seconds since 1970, and only the core
/// reads or writes it.
public sealed record SyncRecord(SyncRecordKind Kind, Guid Id, Guid SpaceId, SyncVersion Version, int Schema, byte[] Body, bool IsTombstone);

/// One synced record by identity: its kind, and the identity it has as that
/// kind. A tab and the archive entry it becomes share an identity, so the kind
/// tells them apart.
public sealed record SyncRecordReference(SyncRecordKind Kind, Guid Id);

#endregion
