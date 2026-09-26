namespace CrestCore.Contracts;

/// Sync starts on this device: whether the person turned it on, and whether
/// this build can reach Crest's CloudKit container at all.
public sealed record ConfigureCloudSync(bool IsEnabled, bool CanReachCloud) : CloudSyncControlIntent;
