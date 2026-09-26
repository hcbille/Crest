namespace CrestCore.Contracts;

/// Turns one on-or-off link preference on or off.
public sealed record SetLinkBehavior(LinkBehavior Behavior, bool IsOn) : LinkIntent;
