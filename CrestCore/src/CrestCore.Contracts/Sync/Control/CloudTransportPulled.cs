namespace CrestCore.Contracts;

/// The transport pulled and merged the `CloudRecords` records the cloud held.
/// `LocalChangesUnsaved` is as `CloudTransportSynced` has it.
public sealed record CloudTransportPulled(long Attempt, int CloudRecords, bool LocalChangesUnsaved) : CloudSyncControlIntent;
