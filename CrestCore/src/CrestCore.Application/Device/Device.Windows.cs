using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

internal sealed partial class Device {
    #region Actions - Intents

    /// Runs one window intent, publishing what it changed to `changes`.
    public void Handle(WindowIntent intent, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        switch (intent) {
            case OpenWindow opening: Open(opening, changes); break;
            case CloseWindow closing: Close(closing, changes); break;
            case ShowSpace showing: Show(showing, changes); break;
            case ShowTab showing: Show(showing, changes); break;
            case ShowAdjacentTab stepping: Show(stepping, changes); break;
            case ShowAdjacentSpace stepping: Show(stepping, changes); break;
            case ShowMostRecentTab recent: Show(recent, changes); break;
            case DismissShownTab dismissing: Dismiss(dismissing, changes); break;
            case ResizeSplitColumns resizing: Resize(resizing, changes); break;
            case AdoptWindowRecords adoption: Adopt(adoption, changes); break;
            default: throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "The device does not handle this intent.");
        }
    }

    private void Open(OpenWindow intent, ChangeFeed changes) {
        var authority = Workspace(intent.WorkspaceId);
        var session = authority.Current;
        lock (gate) {
            if (open.TryGetValue(intent.WindowId, out var existing)) {
                Publishing(existing, session);
                changes.Publish(new WindowChanged(published[existing.Id]));
                return;
            }
            if (intent.Saved && intent.WorkspaceId != persistentWorkspace)
                throw new Rejected(new UnsavedWorkspace(intent.WorkspaceId));
            var window = intent.Saved && saved.TryGetValue(intent.WindowId, out var record)
                ? Window.Restoring(record, intent.WorkspaceId)
                : intent.CopyingWindowId is { } copied && open.TryGetValue(copied, out var source) && source.WorkspaceId == intent.WorkspaceId
                    ? Window.Copying(source, intent.WindowId, intent.Saved)
                    : Window.Launching(intent.WindowId, intent.WorkspaceId, intent.Saved, session,
                        intent.WorkspaceId == persistentWorkspace ? legacyTabs : new Dictionary<Guid, Guid>());
            if (!intent.RestoresTabs) window.ForgetTabs();
            foreach (var shown in intent.ShowingTabs) window.ShowTab(shown.SpaceId, shown.TabId, moves: false);
            if (intent.ShowingSpaceId is { } showing && session.Spaces.Any(space => space.Id == showing)) window.MoveTo(showing);
            window.Repair(session);
            open[window.Id] = window;
            changes.Publish(Publishing(window, session)!);
        }
    }

    private void Close(CloseWindow intent, ChangeFeed changes) {
        lock (gate) {
            if (!open.Remove(intent.WindowId)) return;
            published.Remove(intent.WindowId);
        }
        changes.Publish(new WindowClosed(intent.WindowId));
    }

    private void Show(ShowSpace intent, ChangeFeed changes) {
        var window = Opened(intent.WindowId);
        var session = Workspace(window.WorkspaceId).Current;
        if (Available(session, intent.SpaceId) is not { } space || window.ShownSpaceId == space.Id) return;
        lock (gate) Publish(Changing([window], shown => shown.ShowSpace(space), session), changes);
    }

    /// Showing a tab records its use first, as its own change to the
    /// workspace, so cleanup never archives what a window just showed. A
    /// workspace that takes no edits records nothing and still shows it.
    private void Show(ShowTab intent, ChangeFeed changes) {
        var window = Opened(intent.WindowId);
        var authority = Workspace(window.WorkspaceId);
        if (Available(authority.Current, intent.SpaceId) is not { } space) return;
        if (intent.TabId is { } tabId) {
            if (space.Tabs.All(tab => tab.Id != tabId)) return;
            if (authority.Touch(intent.SpaceId, tabId, DateTimeOffset.UtcNow) is { } touched)
                Publish(SessionChanges.Publish(window.WorkspaceId, touched.Previous, touched.Next), changes);
        }
        var session = authority.Current;
        lock (gate) Publish(Changing([window], shown => shown.ShowTab(intent.SpaceId, intent.TabId, moves: true), session), changes);
    }

    /// Steps the window's tab through its Space's sidebar, showing the tab the
    /// step reaches the way `ShowTab` does.
    private void Show(ShowAdjacentTab intent, ChangeFeed changes) {
        var window = Opened(intent.WindowId);
        var session = Workspace(window.WorkspaceId).Current;
        Guid spaceId;
        Guid? shown;
        lock (gate) {
            spaceId = window.ShownSpaceId;
            shown = window.Tab(spaceId);
        }
        if (Available(session, spaceId) is not { } space || shown is not { } tabId || space.Step(tabId, intent.Direction) is not { } next)
            return;
        Show(new ShowTab(intent.WindowId, space.Id, next), changes);
    }

    /// Shows the tab of the window's Space used most recently other than the
    /// one it shows, the way `ShowTab` does.
    private void Show(ShowMostRecentTab intent, ChangeFeed changes) {
        var window = Opened(intent.WindowId);
        var session = Workspace(window.WorkspaceId).Current;
        Guid spaceId;
        Guid? shown;
        lock (gate) {
            spaceId = window.ShownSpaceId;
            shown = window.Tab(spaceId);
        }
        if (Available(session, spaceId) is not { } space || shown is not { } tabId
            || space.Tabs.Where(tab => tab.Id != tabId).MaxBy(tab => tab.LastActivatedAt) is not { } recent) return;
        Show(new ShowTab(intent.WindowId, space.Id, recent.Id), changes);
    }

    /// Steps the window through the Spaces it may show, showing the one the
    /// step reaches the way `ShowSpace` does.
    private void Show(ShowAdjacentSpace intent, ChangeFeed changes) {
        var window = Opened(intent.WindowId);
        var spaces = Window.Showable(Workspace(window.WorkspaceId).Current).ToList();
        int shown;
        lock (gate) shown = spaces.FindIndex(space => space.Id == window.ShownSpaceId);
        if (spaces.Count < 2 || shown < 0) return;
        Show(new ShowSpace(intent.WindowId, spaces[intent.Direction.From(shown, spaces.Count)].Id), changes);
    }

    /// The window returns to the tab it showed before, recording its use the
    /// way showing a tab does, or shows nothing in that Space.
    private void Dismiss(DismissShownTab intent, ChangeFeed changes) {
        var window = Opened(intent.WindowId);
        var authority = Workspace(window.WorkspaceId);
        if (Available(authority.Current, intent.SpaceId) is not { } space) return;
        Guid? fallback;
        lock (gate) {
            if (window.Tab(space.Id) != intent.TabId) return;
            fallback = window.DismissalFallback(space.Id, intent.TabId, space.Tabs.Select(tab => tab.Id).ToHashSet());
        }
        if (fallback is { } tabId && authority.Touch(space.Id, tabId, DateTimeOffset.UtcNow) is { } touched)
            Publish(SessionChanges.Publish(window.WorkspaceId, touched.Previous, touched.Next), changes);
        var session = authority.Current;
        lock (gate) Publish(Changing([window], shown => shown.ShowTab(space.Id, fallback, moves: false), session), changes);
    }

    private void Resize(ResizeSplitColumns intent, ChangeFeed changes) {
        var window = Opened(intent.WindowId);
        var session = Workspace(window.WorkspaceId).Current;
        if (Window.SplitShares(intent.Shares) is null) throw new Rejected(new InvalidSplitColumnShares());
        lock (gate) Publish(Changing([window], resized => {
            resized.Resize(intent.GroupId, intent.Shares);
            resized.Repair(session);
        }, session), changes);
    }

    private static void Publish(IEnumerable<Change> published, ChangeFeed changes) {
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

    /// Where a lift in a window's sidebar may drop: each drop it could commit,
    /// checked as the drop would be now, at the end of each list.
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
        ListDropTarget[] lists = [.. space.Sidebar.Lists.Select(list => new ListDropTarget(list.Section, list.FolderId, Refusal(authority,
            new DropIntoList(workspaceId, windowId, spaceId, selection, list.Section, list.FolderId, BeforeTabId: null, BeforeFolderId: null),
            now, pages)))];
        SpaceDropTarget[] spaces = [.. Window.Showable(session).Where(other => other.Id != spaceId).Select(other => new SpaceDropTarget(other.Id,
            Refusal(authority, new DropOnSpace(workspaceId, windowId, spaceId, selection, other.Id, Follows: false), now, pages)))];
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

    /// The attached workspace, or `UnknownWorkspace`.
    internal NativeSessionAuthority Workspace(Guid workspaceId) {
        lock (gate)
            return workspaces.TryGetValue(workspaceId, out var authority) ? authority : throw new Rejected(new UnknownWorkspace(workspaceId));
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
    private static SpaceState? Available(SessionState session, Guid spaceId) =>
        session.SpaceDeletions.Any(deletion => deletion.SpaceId == spaceId) ? null : session.Spaces.FirstOrDefault(space => space.Id == spaceId);

    #endregion
}
