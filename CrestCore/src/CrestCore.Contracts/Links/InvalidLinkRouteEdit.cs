namespace CrestCore.Contracts;

/// A route edit gives no field, more than one, or an empty Space.
public sealed record InvalidLinkRouteEdit(Guid RouteId) : Rejection;
