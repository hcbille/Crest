namespace CrestCore.Contracts;

#region Queries

/// What following `Url` from a page does: load in the page, open in Peek, or
/// open in a new tab in front or behind. The page's tab, how a page with no
/// tab presents, the gesture and this device's link preferences decide it. A
/// page the core does not host loads the link itself.
public sealed record LinkNavigation(Guid PageId, string? Url, LinkGesture Gesture) : Query<LinkNavigationAnswer>;

/// Whether a window a page opens, once its engine accepted the request, comes
/// to the front as the selected tab: an ordinary new-window request does, and
/// one made with the new-tab gesture follows this device's link preferences,
/// which Shift reverses.
public sealed record OpenedWindowSelection(LinkGesture Gesture) : Query<OpenedWindowSelected>;

/// Whether the window a page opened comes to the front.
public sealed record OpenedWindowSelected(bool Selects);

/// Where a link another app hands a window opens: the first enabled route that
/// matches and whose Space can open, else the external-link destination, both
/// read from this device's preferences. A link never opens in a locked Space
/// on another app's behalf: it opens in a Quick Window on the window's Space
/// when that one is unlocked, else on the first unlocked Space, and nowhere
/// when every Space is locked.
public sealed record RouteExternalLink(Guid WindowId, string Url) : Query<ExternalLinkPlacement>;

/// The Space an external link opens in and whether it opens as a Quick Window
/// there. `SubstitutesForLockedSpace` says the routed Space was locked and this
/// one stands in for it. `SpaceId` is null when no Space may take the link.
public sealed record ExternalLinkPlacement(Guid? SpaceId, bool OpensQuickWindow, bool SubstitutesForLockedSpace);

#endregion

#region Changes

/// This device's link preferences changed, or were read as it opened.
public sealed record LinkPreferencesChanged(LinkPreferences Preferences) : Change;

#endregion

#region Rejections

/// A route edit gives no field, more than one, or an empty Space.
public sealed record InvalidLinkRouteEdit(Guid RouteId) : Rejection;

/// A route's pattern is longer than `Maximum` characters.
public sealed record LinkPatternTooLong(int Maximum) : Rejection;

/// A route already has this identity.
public sealed record LinkRouteExists(Guid RouteId) : Rejection;

/// No route more fits: there are already `Maximum`.
public sealed record LinkRoutesFull(int Maximum) : Rejection;

/// No route has this identity.
public sealed record UnknownLinkRoute(Guid RouteId) : Rejection;

#endregion

#region Models

/// How a link was followed: whether a person activated it, whether it loads
/// the whole page, the modifier keys held, and whether it was a middle click.
public sealed record LinkGesture(bool UserActivated, bool TopLevel, ShortcutModifiers Modifiers, bool MiddleClick);

/// What following a link does.
public sealed record LinkNavigationAnswer(LinkNavigationDecision Decision);

/// One ordered rule that sends matching external links to a Space.
public sealed record LinkRoute(Guid Id, bool IsEnabled, LinkRouteMatch Match, string Pattern, Guid DestinationSpaceId);

/// The Space a Quick Window last opened a site in, which the next external
/// link to that site opens in when the preferences remember Spaces by site.
/// `Site` is the lowercased host without a leading `www.`.
public sealed record RememberedSite(string Site, Guid SpaceId);

#endregion
