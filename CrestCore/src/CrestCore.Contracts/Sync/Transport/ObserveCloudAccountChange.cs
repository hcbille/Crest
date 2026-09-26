namespace CrestCore.Contracts;

/// The iCloud account changed as `Transition` says. A change that always
/// pauses sync waits for the person's decision; a sign-in pauses only while
/// an earlier change still waits for one.
public sealed record ObserveCloudAccountChange(CloudAccountTransition Transition) : CloudTransportIntent;
