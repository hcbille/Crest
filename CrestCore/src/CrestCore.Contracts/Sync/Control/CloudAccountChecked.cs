namespace CrestCore.Contracts;

/// What iCloud said of the signed-in account.
public sealed record CloudAccountChecked(long Attempt, CloudAccountState State) : CloudSyncControlIntent;
