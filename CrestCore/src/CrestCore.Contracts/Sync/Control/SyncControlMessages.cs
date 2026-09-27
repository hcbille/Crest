namespace CrestCore.Contracts;

#region Intents

/// Something the platform tells the core about iCloud sync on this device:
/// what the person asked for, and what each step the core asked for came to.
/// The core decides what sync does next and answers `CloudSyncAdvanced`: the
/// status it left and the steps the platform takes, in order, reporting each
/// one's result back. A step names the attempt it belongs to, and a result
/// for an attempt that is no longer current changes only what the core says
/// it must.
public abstract record CloudSyncControlIntent : Intent;

/// The person chose which copy to keep after the account changed: the
/// cloud's in place of this device's when `UsesCloud`, or this device's over
/// the cloud's.
public sealed record ChooseCloudCopy(bool UsesCloud) : CloudSyncControlIntent;

/// What iCloud said of the signed-in account.
public sealed record CloudAccountChecked(long Attempt, CloudAccountState State) : CloudSyncControlIntent;

/// How this device's content compares with the `CloudRecords` records the
/// cloud held.
public sealed record CloudContentCompared(long Attempt, int CloudRecords, CloudContentComparison Comparison) : CloudSyncControlIntent;

/// This device, which held nothing, took the cloud's content.
public sealed record CloudContentTaken(long Attempt) : CloudSyncControlIntent;

/// The copy the person chose was applied over the `CloudRecords` records the
/// cloud held.
public sealed record CloudCopyApplied(long Attempt, bool UsesCloud, int CloudRecords) : CloudSyncControlIntent;

/// Whether this build holds the entitlement for Crest's container.
public sealed record CloudEntitlementChecked(long Attempt, bool Granted) : CloudSyncControlIntent;

/// The disposable seed was replaced with the `CloudRecords` records the
/// cloud held.
public sealed record CloudSeedReplaced(long Attempt, int CloudRecords) : CloudSyncControlIntent;

/// The step `Step` failed, as `Message` says. `ObservedCloudRecords` counts
/// the records the cloud held when a snapshot loaded before the failure.
public sealed record CloudStepFailed(long Attempt, CloudSyncStepKind Step, string Message, int? ObservedCloudRecords)
    : CloudSyncControlIntent;

/// The transport pulled and merged the `CloudRecords` records the cloud held.
/// `LocalChangesUnsaved` is as `CloudTransportSynced` has it.
public sealed record CloudTransportPulled(long Attempt, int CloudRecords, bool LocalChangesUnsaved) : CloudSyncControlIntent;

/// The transport started for `Attempt` reported `Report`: `Message` carries a
/// failure's words, `RecordCount` counts a batch or the skipped records, and
/// `RequiresAppUpdate` tells whether a newer build wrote records it skipped.
public sealed record CloudTransportReported(long Attempt, CloudTransportReport Report, string? Message, int RecordCount,
    bool RequiresAppUpdate) : CloudSyncControlIntent;

/// The transport started.
public sealed record CloudTransportStarted(long Attempt) : CloudSyncControlIntent;

/// The transport fetched and sent without failing. `LocalChangesUnsaved`
/// tells whether the core could not stage or save this device's latest
/// edits meanwhile.
public sealed record CloudTransportSynced(long Attempt, bool LocalChangesUnsaved) : CloudSyncControlIntent;

/// Sync starts on this device: whether the person turned it on, and whether
/// this build can reach Crest's CloudKit container at all.
public sealed record ConfigureCloudSync(bool IsEnabled, bool CanReachCloud) : CloudSyncControlIntent;

/// This device staged local changes for the transport to upload.
public sealed record NotifyCloudLocalChanges : CloudSyncControlIntent;

/// iCloud said the signed-in account may have changed: sync starts again
/// against whichever account is signed in now.
public sealed record ObserveCloudAccountAvailability : CloudSyncControlIntent;

/// The person confirmed a pull of everything iCloud holds. A pull merges the
/// cloud's content; it never takes either side in place of the other.
public sealed record RequestCloudPull : CloudSyncControlIntent;

/// The person asked to sync now: the running transport fetches and sends, or
/// sync starts when none runs.
public sealed record RequestCloudSync : CloudSyncControlIntent;

/// The restart an account change asked for is due.
public sealed record RestartCloudSyncAfterAccountChange : CloudSyncControlIntent;

/// The retry the core scheduled is due.
public sealed record RetryCloudSync : CloudSyncControlIntent;

/// The person turned sync on or off. Turning it off stops the transport and
/// starts its state over, except while an account decision waits: turning
/// sync off is not an answer to whether this is the same iCloud account.
public sealed record SetCloudSyncEnabled(bool IsEnabled) : CloudSyncControlIntent;

/// Brings sync up against the account that is signed in now, unless it is
/// off, already starting, or running.
public sealed record StartCloudSync : CloudSyncControlIntent;

#endregion

#region Queries

/// iCloud sync's status on this device.
public sealed record CloudSync : Query<CloudSyncStatus>;

#endregion

#region Changes

/// The status iCloud sync is in, and the steps the platform takes next, in
/// order.
public sealed record CloudSyncAdvanced(CloudSyncStatus Status, IReadOnlyList<CloudSyncStep> Steps) : Change;

/// One step the platform takes for iCloud sync, for the start or sync
/// `Attempt` names. `UsesCloud` tells `ApplyChosenCopy` which copy the person
/// chose.
public sealed record CloudSyncStep(CloudSyncStepKind Kind, long Attempt, bool UsesCloud);

#endregion

#region Models

/// iCloud sync on this device, as the settings and diagnostics show it.
/// `Problem` names a reason the core found; `FailureMessage` is a failure the
/// platform reported in its own words; at most one of them holds. `Conflict`
/// compares this device's content and the cloud's while the person has to
/// choose which to keep. `ObservedCloudRecords` counts the records the cloud
/// held when a snapshot last loaded.
public sealed record CloudSyncStatus(
    bool IsEnabled,
    CloudAccountState Account,
    CloudSyncPhase Phase,
    CloudSyncProblem? Problem,
    string? FailureMessage,
    DateTimeOffset? LastAttemptAt,
    DateTimeOffset? LastSuccessAt,
    int LastFetchedRecords,
    int LastUploadedRecords,
    int? ObservedCloudRecords,
    CloudContentComparison? Conflict,
    int SkippedRecords,
    bool RequiresAppUpdate,
    bool CloudDataRemoved);

#endregion
