namespace CrestCore.Contracts;

/// No route has this identity.
public sealed record UnknownLinkRoute(Guid RouteId) : Rejection;
