namespace CrestCore.Contracts;

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
