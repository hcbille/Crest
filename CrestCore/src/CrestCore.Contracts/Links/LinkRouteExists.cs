namespace CrestCore.Contracts;

/// A route already has this identity.
public sealed record LinkRouteExists(Guid RouteId) : Rejection;
