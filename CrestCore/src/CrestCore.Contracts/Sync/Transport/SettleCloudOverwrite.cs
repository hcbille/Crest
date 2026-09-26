namespace CrestCore.Contracts;

/// Ends this device's overwrite of the cloud once the journal of the session
/// the core keeps in its file holds nothing waiting to upload, after every
/// stage queued before it settled. Refused with `NoStoredSession` or
/// `StoredSessionClosed` as a `CloudSyncIntent` is.
public sealed record SettleCloudOverwrite : CloudTransportIntent;
