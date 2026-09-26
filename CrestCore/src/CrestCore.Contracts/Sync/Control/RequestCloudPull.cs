namespace CrestCore.Contracts;

/// The person confirmed a pull of everything iCloud holds. A pull merges the
/// cloud's content; it never takes either side in place of the other.
public sealed record RequestCloudPull : CloudSyncControlIntent;
