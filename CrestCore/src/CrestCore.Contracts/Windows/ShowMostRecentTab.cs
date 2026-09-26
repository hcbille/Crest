namespace CrestCore.Contracts;

/// Shows the tab of the window's Space used most recently other than the one
/// it shows, recording its use as `ShowTab` does. Publishes nothing when the
/// window shows no tab or the Space holds no other.
public sealed record ShowMostRecentTab(Guid WindowId) : WindowIntent;
