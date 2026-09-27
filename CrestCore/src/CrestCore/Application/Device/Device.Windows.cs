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

    /// Whether a dragged tab may leave its window: the window still shows the
    /// Space the drag started in, with the profile it had and not being
    /// deleted, the Space is unlocked and holds the tab, and the drag carries
    /// that tab alone.
    public TearOffPermission Answer(CanTearOff question) {
        ArgumentNullException.ThrowIfNull(question);
        var window = Opened(question.WindowId);
        var authority = Workspace(window.WorkspaceId);
        var space = Available(authority.Current, question.SpaceId);
        if (space is null || space.ProfileId != question.ProfileId) return Refused(TearOffRefusal.SpaceChanged);
        if (authority.IsLocked(space)) return Refused(TearOffRefusal.SpaceLocked);
        if (space.Tabs.All(tab => tab.Id != question.TabId)) return Refused(TearOffRefusal.TabGone);
        if (question.DraggedTabs is { } dragged && (dragged.Count != 1 || dragged[0] != question.TabId))
            return Refused(TearOffRefusal.SeveralTabs);
        return new(Allowed: true, Reason: null);

        static TearOffPermission Refused(TearOffRefusal reason) => new(Allowed: false, reason);
    }

    /// The tab "Split With Next Tab" adds to the split of the tab a window
    /// shows: the next free tab row in its sidebar list, when the core would
    /// join it.
    public SplitJoinCandidateTab Answer(SplitJoinCandidate question, DateTimeOffset now, Pages pages) {
        ArgumentNullException.ThrowIfNull(question);
        var window = Opened(question.WindowId);
        var authority = Workspace(window.WorkspaceId);
        Guid spaceId;
        Guid? shown;
        lock (gate) {
            spaceId = window.ShownSpaceId;
            shown = window.Tab(spaceId);
        }
        if (Available(authority.Current, spaceId) is not { } space || shown is not { } tabId
            || space.SplitCandidate(tabId) is not { } candidate) return new(TabId: null);
        var joining = new JoinSplit(window.WorkspaceId, question.WindowId, space.Id, candidate, tabId, Index: null);
        return new(Refusal(authority, joining, now, pages) is null ? candidate : null);
    }

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

    /// Where a lift in a window's sidebar may drop: the lists and Spaces it
    /// may reach, and the cards on show, whose join is checked now. The lists
    /// and Spaces are checked as the lift reaches them.
    public DropTargetList Answer(DropTargets question, DateTimeOffset now, Pages pages) {
        ArgumentNullException.ThrowIfNull(question);
        var window = Opened(question.WindowId);
        var authority = Workspace(question.WorkspaceId);
        try {
            authority.CheckLift(question.WindowId, question.SpaceId, question.Selection);
        } catch (Rejected refused) {
            return new(refused.Rejection, [], [], Split: null, []);
        }
        var session = authority.Current;
        var space = session.Spaces.First(candidate => candidate.Id == question.SpaceId);
        var (workspaceId, windowId, spaceId, selection) = (question.WorkspaceId, question.WindowId, question.SpaceId, question.Selection);
        ListDropTarget[] lists = [.. space.Sidebar.Lists.Select(list => new ListDropTarget(list.Section, list.FolderId))];
        Guid[] spaces = [.. Window.Showable(session).Where(other => other.Id != spaceId).Select(other => other.Id)];
        Guid? shown;
        lock (gate) shown = window.Tab(spaceId);
        var split = shown is { } target
            ? new SplitDropTarget(target, Refusal(authority, new DropIntoSplit(workspaceId, windowId, spaceId, selection, target, Index: null),
                now, pages))
            : null;
        // Every candidate passes the rule a drop checks of its tab, so the first
        // answers for all of them what the lift allows.
        var lifted = selection.MemberTabIds.ToHashSet();
        var tabs = space.Tabs.ToDictionary(tab => tab.Id);
        Guid[] around = [.. space.Sidebar.Lists.Where(list => list.FolderId is null && !list.Section.IsDurable)
            .SelectMany(list => list.Rows)
            .Where(row => row.Kind == SidebarRowKind.Tab && tabs[row.Id].SplitGroupId is null && !lifted.Contains(row.Id))
            .Select(row => row.Id)];
        if (around.Length > 0
            && Refusal(authority, new DropAroundTab(workspaceId, windowId, spaceId, selection, around[0]), now, pages) is not null)
            around = [];
        return new(Refusal: null, lists, spaces, split, around);
    }

    /// The rule that would refuse `intent` in `authority` now, or null when it
    /// would be accepted. The identities a check draws are never used.
    private static Rejection? Refusal(NativeSessionAuthority authority, SessionIntent intent, DateTimeOffset now, Pages pages) {
        try {
            authority.Check(intent, now, new SystemIdSource(), pages);
            return null;
        } catch (Rejected refused) {
            return refused.Rejection;
        }
    }

    /// Where each numbered command leads in a window: to the stops of the Space
    /// it shows, each to its first tab, and to the Spaces it may show.
    public NumberedSelectionList Answer(NumberedSelections question) {
        ArgumentNullException.ThrowIfNull(question);
        var window = Opened(question.WindowId);
        var session = Workspace(window.WorkspaceId).Current;
        Guid spaceId;
        lock (gate) spaceId = window.ShownSpaceId;
        var choices = new NumberedChoices(spaceId, Available(session, spaceId) is { } space ? [.. space.Stops().Select(stop => stop.Members[0])] : [],
            [.. Window.Showable(session).Select(showable => showable.Id)]);
        return new([.. ShortcutCommand.All.Select(command => command.Selecting(choices)).OfType<NumberedSelection>()]);
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

    /// The Space a window may show: one the session holds that is not being deleted.
    internal static SpaceState? Available(SessionState session, Guid spaceId) =>
        session.SpaceDeletions.Any(deletion => deletion.SpaceId == spaceId) ? null : session.Spaces.FirstOrDefault(space => space.Id == spaceId);

    #endregion
}
