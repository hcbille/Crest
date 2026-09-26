namespace CrestCore.Contracts;

/// The step `Step` failed, as `Message` says. `ObservedCloudRecords` counts
/// the records the cloud held when a snapshot loaded before the failure.
public sealed record CloudStepFailed(long Attempt, CloudSyncStepKind Step, string Message, int? ObservedCloudRecords)
    : CloudSyncControlIntent;
