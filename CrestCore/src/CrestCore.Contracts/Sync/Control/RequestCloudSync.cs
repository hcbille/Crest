namespace CrestCore.Contracts;

/// The person asked to sync now: the running transport fetches and sends, or
/// sync starts when none runs.
public sealed record RequestCloudSync : CloudSyncControlIntent;
