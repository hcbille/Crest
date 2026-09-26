namespace CrestCore.Contracts;

/// The transport fetched and sent without failing. `LocalChangesUnsaved`
/// tells whether the core could not stage or save this device's latest
/// edits meanwhile.
public sealed record CloudTransportSynced(long Attempt, bool LocalChangesUnsaved) : CloudSyncControlIntent;
