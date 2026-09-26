namespace CrestCore.Contracts;

/// Keeps the server fields of `Updated`, replacing what was kept of each, and
/// forgets those of `Removed`.
[MessageLimit(64 * 1024 * 1024)]
public sealed record RecordCloudFields(IReadOnlyList<CloudRecordFields> Updated, IReadOnlyList<string> Removed)
    : CloudTransportIntent;
