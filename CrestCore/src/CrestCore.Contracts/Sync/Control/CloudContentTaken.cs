namespace CrestCore.Contracts;

/// This device, which held nothing, took the cloud's content.
public sealed record CloudContentTaken(long Attempt) : CloudSyncControlIntent;
