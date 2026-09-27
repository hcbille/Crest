using CrestCore.Contracts;

namespace CrestCore.Domain;

/// This device's link preferences before it chooses any, and the rules that
/// edit them: the ordered routes, the sites remembered for Quick Windows, and
/// what a deleted Space leaves behind. Each edit answers the revised
/// preferences, or throws the rule that refuses it.
public static class LinkPreferencePolicy {
    #region Static Variables

    /// The preferences of a device that never chose any.
    public static readonly LinkPreferences Default = new(ExternalLinkDestination.QuickWindow, DestinationSpaceId: null,
        FocusesNewTabs: false, FollowsMovedTabs: true, OpensPeekAutomatically: true, LinkPeekModifier.Option,
        DragsLinksToPeek: true, QuickWindowArchivePolicy.After6Hours, RemembersSpaceBySite: true, [], []);

    #endregion

    #region Actions - Route edits

    /// A new route starts enabled, matching by containment, with an empty
    /// pattern the person fills in; an empty pattern never matches.
    public static LinkPreferences Adding(LinkPreferences preferences, AddLinkRoute intent) {
        ArgumentNullException.ThrowIfNull(preferences);
        ArgumentNullException.ThrowIfNull(intent);
        if (preferences.Routes.Count >= AddLinkRoute.MaximumRoutes) throw new Rejected(new LinkRoutesFull(AddLinkRoute.MaximumRoutes));
        if (intent.RouteId == Guid.Empty || preferences.Routes.Any(route => route.Id == intent.RouteId))
            throw new Rejected(new LinkRouteExists(intent.RouteId));
        if (intent.DestinationSpaceId == Guid.Empty) throw new Rejected(new InvalidLinkRouteEdit(intent.RouteId));
        return preferences with {
            Routes = [.. preferences.Routes, new LinkRoute(intent.RouteId, true, LinkRouteMatch.Contains, "", intent.DestinationSpaceId)]
        };
    }

    /// Changes exactly one field, so concurrent edits to other fields of the
    /// same route are never overwritten by a stale copy.
    public static LinkPreferences Editing(LinkPreferences preferences, EditLinkRoute edit) {
        ArgumentNullException.ThrowIfNull(preferences);
        ArgumentNullException.ThrowIfNull(edit);
        var route = Route(preferences, edit.RouteId);
        int supplied = (edit.IsEnabled is null ? 0 : 1) + (edit.Match is null ? 0 : 1) + (edit.Pattern is null ? 0 : 1)
            + (edit.DestinationSpaceId is null ? 0 : 1);
        if (supplied != 1 || edit.DestinationSpaceId == Guid.Empty) throw new Rejected(new InvalidLinkRouteEdit(edit.RouteId));
        if (edit.Pattern is { Length: > EditLinkRoute.MaximumPatternLength })
            throw new Rejected(new LinkPatternTooLong(EditLinkRoute.MaximumPatternLength));
        var edited = route with {
            IsEnabled = edit.IsEnabled ?? route.IsEnabled,
            Match = edit.Match ?? route.Match,
            Pattern = edit.Pattern ?? route.Pattern,
            DestinationSpaceId = edit.DestinationSpaceId ?? route.DestinationSpaceId
        };
        return preferences with { Routes = [.. preferences.Routes.Select(candidate => candidate.Id == edit.RouteId ? edited : candidate)] };
    }

    /// Moves one route by an offset; a move past either end changes nothing.
    public static LinkPreferences Moving(LinkPreferences preferences, MoveLinkRoute move) {
        ArgumentNullException.ThrowIfNull(preferences);
        ArgumentNullException.ThrowIfNull(move);
        var route = Route(preferences, move.RouteId);
        var routes = preferences.Routes.ToList();
        int source = routes.IndexOf(route);
        long destination = (long)source + move.Offset;
        if (destination < 0 || destination >= routes.Count) return preferences;
        routes.RemoveAt(source);
        routes.Insert((int)destination, route);
        return preferences with { Routes = routes };
    }

    public static LinkPreferences Removing(LinkPreferences preferences, RemoveLinkRoute removal) {
        ArgumentNullException.ThrowIfNull(preferences);
        ArgumentNullException.ThrowIfNull(removal);
        var route = Route(preferences, removal.RouteId);
        return preferences with { Routes = [.. preferences.Routes.Where(candidate => candidate != route)] };
    }

    #endregion

    #region Actions - Sites

    /// Remembers `spaceId` for `url`'s site while the preferences remember
    /// Spaces by site and the address has a host; otherwise changes nothing.
    public static LinkPreferences Remembering(LinkPreferences preferences, string url, Guid spaceId) {
        ArgumentNullException.ThrowIfNull(preferences);
        if (!preferences.RemembersSpaceBySite || LinkRoutingPolicy.Site(url) is not { } site) return preferences;
        return preferences with {
            RememberedSites = [.. preferences.RememberedSites.Where(remembered => remembered.Site != site), new RememberedSite(site, spaceId)]
        };
    }

    #endregion

    #region Actions - Space deletion

    /// A deleted Space takes its routes with it, stops being the chosen
    /// external-link Space, and is forgotten for every site that remembered it.
    /// Routing already skips missing Spaces; this keeps the stored preferences
    /// from pointing at a Space that no longer exists.
    public static LinkPreferences Forgetting(LinkPreferences preferences, Guid spaceId) {
        ArgumentNullException.ThrowIfNull(preferences);
        return preferences with {
            Routes = [.. preferences.Routes.Where(route => route.DestinationSpaceId != spaceId)],
            DestinationSpaceId = preferences.DestinationSpaceId == spaceId ? null : preferences.DestinationSpaceId,
            RememberedSites = [.. preferences.RememberedSites.Where(remembered => remembered.SpaceId != spaceId)]
        };
    }

    #endregion

    #region Mutators

    private static LinkRoute Route(LinkPreferences preferences, Guid routeId) =>
        preferences.Routes.FirstOrDefault(route => route.Id == routeId) ?? throw new Rejected(new UnknownLinkRoute(routeId));

    #endregion
}
