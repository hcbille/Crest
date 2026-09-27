namespace CrestCore.Contracts;

#region Queries

/// Whether a tab dragged out of a window may leave it for a window of its
/// own. `DraggedTabs` is the multi-selection the drag carries, or null when
/// it carries the one tab.
public sealed record CanTearOff(Guid WindowId, Guid SpaceId, Guid ProfileId, Guid TabId, IReadOnlyList<Guid>? DraggedTabs)
    : Query<TearOffPermission>;

/// Whether a dragged tab may leave its window, and when it may not, why.
public sealed record TearOffPermission(bool Allowed, TearOffRefusal? Reason);

/// Why a dragged tab may not leave its window.
public enum TearOffRefusal {
    /// The window no longer shows the Space the drag started in, with the
    /// profile it had, or the Space is being deleted.
    SpaceChanged,
    /// The Space is locked.
    SpaceLocked,
    /// The Space no longer holds the tab.
    TabGone,
    /// The drag carries more than the one tab.
    SeveralTabs
}

/// Which tab a Space shows when no window chose one, for a draft Space the
/// session does not hold yet, given its tabs' placements in Space order: the
/// first open tab, else the first pinned one, else the first tab.
public sealed record FallbackTab(IReadOnlyList<TabPlacement> Placements) : Query<FallbackTabIndex>;

/// The index of a draft Space's fallback tab among the placements asked
/// about, or null for a Space without tabs.
public sealed record FallbackTabIndex(int? Index);

/// The tab "Split With Next Tab" adds to the split of the tab a window shows:
/// the first tab row after the row that holds it, in the same list of its
/// Space's sidebar (its section's top level, or its folder's inside), whose tab
/// is in no split, when the core would join it; or none.
public sealed record SplitJoinCandidate(Guid WindowId) : Query<SplitJoinCandidateTab>;

/// The tab "Split With Next Tab" would add, or null when it would add none.
public sealed record SplitJoinCandidateTab(Guid? TabId);

#endregion

#region Changes

/// An open window shows something else: it opened, a person chose what it
/// shows, or the session changed under it and the core repaired it.
public sealed record WindowChanged(WindowState Window) : Change;

/// A window is no longer open.
public sealed record WindowClosed(Guid WindowId) : Change;

/// The device store holds the window records an installed release kept.
/// `Layouts` are the sidebar values those records also carried, which the
/// platform keeps as its own; the core keeps none of them.
public sealed record WindowRecordsAdopted(IReadOnlyList<WindowLayout> Layouts) : Change;

/// The sidebar a window kept: its width and whether it was presented, each
/// absent when the window never set it.
public sealed record WindowLayout(Guid WindowId, double? SidebarWidth, bool? SidebarIsPresented);

#endregion

#region Rejections

/// The shares cannot describe a split's columns: none, more than a split may
/// hold, or one that is not a finite share greater than zero and at most the
/// whole width.
public sealed record InvalidSplitColumnShares : Rejection;

/// The Space is locked, and this process holds no grant to read or change it.
public sealed record SpaceLocked(Guid SpaceId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "The Space is locked or no longer active. Unlock it and select the tabs again.";

    #endregion
}

/// The intent names a workspace that is not attached to this device.
public sealed record UnknownWorkspace(Guid WorkspaceId) : Rejection;

/// Only a window over the persistent session may be saved; this workspace
/// lives in memory.
public sealed record UnsavedWorkspace(Guid WorkspaceId) : Rejection;

/// The intent names a window that is not open.
public sealed record WindowNotOpen(Guid WindowId) : Rejection;

#endregion

#region Models

/// The tab a window shows in one Space, or none.
public sealed record ShownTab(Guid SpaceId, Guid? TabId);

#endregion
