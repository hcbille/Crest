namespace CrestCore.Contracts;

/// The transport started.
public sealed record CloudTransportStarted(long Attempt) : CloudSyncControlIntent;
