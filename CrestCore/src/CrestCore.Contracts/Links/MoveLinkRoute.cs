namespace CrestCore.Contracts;

/// Moves a route `Offset` places among the routes, which match in order. A
/// move past either end changes nothing. Refused with `UnknownLinkRoute`.
public sealed record MoveLinkRoute(Guid RouteId, int Offset) : LinkIntent;
