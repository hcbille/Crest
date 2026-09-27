namespace CrestCore.Contracts;

/// Adds a route, `RouteId`, after the others: enabled, matching by containment
/// and sending to `DestinationSpaceId`, with an empty pattern the person fills
/// in. Refused with `LinkRoutesFull` past `MaximumRoutes`, and with
/// `LinkRouteExists` for an identity already taken.
public sealed record AddLinkRoute(Guid RouteId, Guid DestinationSpaceId) : LinkIntent {
    #region Static Variables

    public const int MaximumRoutes = 64;

    #endregion
}
