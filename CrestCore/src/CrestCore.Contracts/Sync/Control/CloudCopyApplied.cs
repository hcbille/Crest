namespace CrestCore.Contracts;

/// The copy the person chose was applied over the `CloudRecords` records the
/// cloud held.
public sealed record CloudCopyApplied(long Attempt, bool UsesCloud, int CloudRecords) : CloudSyncControlIntent;
