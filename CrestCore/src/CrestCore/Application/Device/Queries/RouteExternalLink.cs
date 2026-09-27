using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Where a link another app hands a window opens: the first enabled route that
/// matches and whose Space can open, else the external-link destination, both
/// read from this device's preferences. A link never opens in a locked Space
/// on another app's behalf: it opens in a Quick Window on the window's Space
/// when that one is unlocked, else on the first unlocked Space, and nowhere
/// when every Space is locked.
public sealed record RouteExternalLink(Guid WindowId, string Url) : Query<ExternalLinkPlacement> {
    #region Actions - Answering

    /// Where a link another app hands a window opens, under this device's
    /// preferences and the Spaces of the window's workspace: none being
    /// deleted, and never a locked one.
    internal override ExternalLinkPlacement Answer(CrestApp app) {
        var window = app.Device.Opened(WindowId);
        var authority = app.Device.Workspace(window.WorkspaceId);
        var spaces = authority.Current.Spaces;
        Guid shown;
        LinkPreferences preferences;
        lock (app.Device.Gate) {
            shown = window.ShownSpaceId;
            preferences = app.Device.Links;
        }
        var context = new LinkRoutingContext([.. spaces.Select(space => space.Id)], shown,
            [.. spaces.Where(space => authority.IsDeleting(space.Id)).Select(space => space.Id)]);
        var locked = spaces.Where(authority.IsLocked).Select(space => space.Id).ToHashSet();
        return LinkRoutingPolicy.DecideExternal(Url, preferences, context, locked) is { } placed
            ? new(placed.SpaceId, placed.OpensQuickWindow, placed.SubstitutesForLockedSpace)
            : new(null, false, false);
    }

    #endregion
}
