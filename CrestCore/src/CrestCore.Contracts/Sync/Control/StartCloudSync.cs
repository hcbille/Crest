namespace CrestCore.Contracts;

/// Brings sync up against the account that is signed in now, unless it is
/// off, already starting, or running.
public sealed record StartCloudSync : CloudSyncControlIntent;
