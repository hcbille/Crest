namespace CrestCore.Contracts;

/// The person chose which copy to keep after the account changed: the
/// cloud's in place of this device's when `UsesCloud`, or this device's over
/// the cloud's.
public sealed record ChooseCloudCopy(bool UsesCloud) : CloudSyncControlIntent;
