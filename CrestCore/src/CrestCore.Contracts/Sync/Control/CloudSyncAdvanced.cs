namespace CrestCore.Contracts;

/// The status iCloud sync is in, and the steps the platform takes next, in
/// order.
public sealed record CloudSyncAdvanced(CloudSyncStatus Status, IReadOnlyList<CloudSyncStep> Steps) : Change;
