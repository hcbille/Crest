namespace CrestCore.Contracts;

/// What the notification request leads to.
public sealed record NotificationRequestAnswer(HostedNotificationRequestAction Action);
