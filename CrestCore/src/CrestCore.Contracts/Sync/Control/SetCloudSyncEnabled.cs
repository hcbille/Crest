namespace CrestCore.Contracts;

/// The person turned sync on or off. Turning it off stops the transport and
/// starts its state over, except while an account decision waits: turning
/// sync off is not an answer to whether this is the same iCloud account.
public sealed record SetCloudSyncEnabled(bool IsEnabled) : CloudSyncControlIntent;
