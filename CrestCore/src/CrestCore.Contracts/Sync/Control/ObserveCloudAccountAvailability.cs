namespace CrestCore.Contracts;

/// iCloud said the signed-in account may have changed: sync starts again
/// against whichever account is signed in now.
public sealed record ObserveCloudAccountAvailability : CloudSyncControlIntent;
