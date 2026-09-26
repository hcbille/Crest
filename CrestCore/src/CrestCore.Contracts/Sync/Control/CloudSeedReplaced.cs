namespace CrestCore.Contracts;

/// The disposable seed was replaced with the `CloudRecords` records the
/// cloud held.
public sealed record CloudSeedReplaced(long Attempt, int CloudRecords) : CloudSyncControlIntent;
