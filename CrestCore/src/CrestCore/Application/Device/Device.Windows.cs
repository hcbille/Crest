using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

internal sealed partial class Device {
    #region Actions - Intents

    /// Runs one window intent, publishing what it changed to the turn's changes.
    public void Handle(WindowIntent intent, DeviceTurn turn) => intent.Apply(this, turn);

    internal static void Publish(IEnumerable<Change> published, ChangeFeed changes) {
        foreach (var change in published) changes.Publish(change);
    }

    #endregion

    #region Actions - Queries

    /// The palette of a window: over the Space it shows, unless that Space is
    /// locked or being deleted, leaving out the tab it shows there.
    public Palette Palette(Guid windowId, bool allowsInternalPages) {
        var window = Opened(windowId);
        var authority = Workspace(window.WorkspaceId);
        Guid spaceId;
        Guid? shown;
        lock (gate) {
            spaceId = window.ShownSpaceId;
            shown = window.Tab(spaceId);
        }
        var space = Available(authority.Current, spaceId);
        if (space is not null && authority.IsLocked(space)) space = null;
        return new(space, shown, authority.Kind.IsPrivate, allowsInternalPages);
    }

    /// The rule that would refuse `intent` in `authority` now, or null when it
    /// would be accepted. The identities a check draws are never used.
    internal static Rejection? Refusal(NativeSessionAuthority authority, SessionIntent intent, DateTimeOffset now, Pages pages) {
        try {
            authority.Check(intent, now, new SystemIdSource(), pages);
            return null;
        } catch (Rejected refused) {
            return refused.Rejection;
        }
    }

    #endregion

    #region Actions - Lookup

    /// The open window, or `WindowNotOpen`.
    internal Window Opened(Guid windowId) {
        lock (gate) return open.TryGetValue(windowId, out var window) ? window : throw new Rejected(new WindowNotOpen(windowId));
    }

    /// Where the open window stands in `spaceId`, or in the Space it shows
    /// when that is null: its workspace, that Space, and the tab it shows
    /// there, if any. Null for a window that is not open.
    internal (Guid WorkspaceId, Guid SpaceId, Guid? TabId)? Showing(Guid windowId, Guid? spaceId) {
        lock (gate) {
            if (!open.TryGetValue(windowId, out var window)) return null;
            var shown = spaceId ?? window.ShownSpaceId;
            return (window.WorkspaceId, shown, window.Tab(shown));
        }
    }

    /// The attached workspace, or `UnknownWorkspace`.
    internal NativeSessionAuthority Workspace(Guid workspaceId) {
        lock (gate)
            return workspaces.TryGetValue(workspaceId, out var authority) ? authority : throw new Rejected(new UnknownWorkspace(workspaceId));
    }

    /// The tabs the open windows over the workspace show on screen: the cards
    /// of the Space each one shows.
    internal IReadOnlySet<Guid> OnScreenTabs(Guid workspaceId) {
        // The session is read outside the device lock, as the windows' rules read it.
        if (Attached(workspaceId)?.Current is not { } session) return new HashSet<Guid>();
        lock (gate)
            return open.Values.Where(window => window.WorkspaceId == workspaceId).SelectMany(window => window.OnScreen(session))
                .ToHashSet();
    }

    /// Whether a window over the workspace shows `tabId` of `spaceId` on
    /// screen: the Space is the one it shows, and it shows the tab or another
    /// member of the tab's split.
    internal bool Shows(Guid workspaceId, Guid spaceId, Guid tabId) {
        lock (gate) {
            if (workspaces.GetValueOrDefault(workspaceId)?.Current.Spaces.FirstOrDefault(space => space.Id == spaceId) is not { } space)
                return false;
            var split = space.Tabs.FirstOrDefault(tab => tab.Id == tabId)?.SplitGroupId;
            return open.Values.Any(window => window.WorkspaceId == workspaceId && window.ShownSpaceId == spaceId
                && window.Tab(spaceId) is { } shown
                && (shown == tabId || split is not null && space.Tabs.Any(tab => tab.Id == shown && tab.SplitGroupId == split)));
        }
    }

    /// The one Space of `profileId` the person may see: held by an attached
    /// workspace, not locked and not being deleted. Null when no Space or more
    /// than one holds the profile.
    internal Guid? OnlySpaceOf(Guid profileId) {
        NativeSessionAuthority[] attached;
        lock (gate) attached = [.. workspaces.Values];
        var owners = attached.SelectMany(workspace => workspace.Current.Spaces.Where(space => space.ProfileId == profileId)
            .Select(space => (Workspace: workspace, Space: space))).DistinctBy(owner => owner.Space.Id).ToList();
        if (owners.Count != 1) return null;
        var (owner, only) = owners[0];
        return owner.IsDeleting(only.Id) || owner.IsLocked(only) ? null : only.Id;
    }

    /// The attached workspace, or null for one that is gone.
    internal NativeSessionAuthority? Attached(Guid workspaceId) {
        lock (gate) return workspaces.GetValueOrDefault(workspaceId);
    }

    /// The workspace the person's own Spaces live in: the session the core
    /// keeps in its file, or in a launch that keeps nothing, the one that keeps
    /// the app's preferences in its place. Null while neither is attached.
    internal (Guid WorkspaceId, NativeSessionAuthority Authority)? Persistent() {
        lock (gate) {
            if (persistentWorkspace is { } kept && workspaces.TryGetValue(kept, out var stored)) return (kept, stored);
            return workspaces.Where(attached => attached.Value.Kind.KeepsAppPreferences)
                .Select(attached => ((Guid, NativeSessionAuthority)?)(attached.Key, attached.Value)).FirstOrDefault();
        }
    }

    /// The Space a window may show: one the session holds that is not being deleted.
    internal static SpaceState? Available(SessionState session, Guid spaceId) =>
        session.SpaceDeletions.Any(deletion => deletion.SpaceId == spaceId) ? null : session.Spaces.FirstOrDefault(space => space.Id == spaceId);

    #endregion
}
