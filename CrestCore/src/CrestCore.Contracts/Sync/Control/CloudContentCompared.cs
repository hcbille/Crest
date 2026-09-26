namespace CrestCore.Contracts;

/// How this device's content compares with the `CloudRecords` records the
/// cloud held.
public sealed record CloudContentCompared(long Attempt, int CloudRecords, CloudContentComparison Comparison) : CloudSyncControlIntent;
