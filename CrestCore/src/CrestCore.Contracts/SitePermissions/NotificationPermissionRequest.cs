namespace CrestCore.Contracts;

/// What a page's request to post notifications leads to, given the saved
/// decision for its site and whether a person's gesture started it.
public sealed record NotificationPermissionRequest(SitePermissionDecision Decision, bool HasUserActivation)
    : Query<NotificationRequestAnswer>;
