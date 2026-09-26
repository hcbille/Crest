namespace CrestCore.Contracts;

/// Removes a route. Refused with `UnknownLinkRoute`.
public sealed record RemoveLinkRoute(Guid RouteId) : LinkIntent;
