namespace CrestCore.Contracts;

/// The transport started for `Attempt` reported `Report`: `Message` carries a
/// failure's words, `RecordCount` counts a batch or the skipped records, and
/// `RequiresAppUpdate` tells whether a newer build wrote records it skipped.
public sealed record CloudTransportReported(long Attempt, CloudTransportReport Report, string? Message, int RecordCount,
    bool RequiresAppUpdate) : CloudSyncControlIntent;
