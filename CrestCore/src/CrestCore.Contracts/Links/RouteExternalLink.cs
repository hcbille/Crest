namespace CrestCore.Contracts;

/// Where a link another app hands a window opens: the first enabled route that
/// matches and whose Space can open, else the external-link destination, both
/// read from this device's preferences. A link never opens in a locked Space
/// on another app's behalf: it opens in a Quick Window on the window's Space
/// when that one is unlocked, else on the first unlocked Space, and nowhere
/// when every Space is locked.
public sealed record RouteExternalLink(Guid WindowId, string Url) : Query<ExternalLinkPlacement>;
