namespace CrestCore.Contracts;

#region Intents - Windows

/// An intent about what one of this device's windows shows. The device owns
/// every window and what it shows; the session never holds any of it.
public abstract record WindowIntent : Intent;

/// Carries the window records an installed release kept in its defaults into
/// the device store, once: what each window showed, the Spaces it had seen and
/// its split columns, folded with the selection that release kept in the
/// session. The store is written before the intent returns; a device that has
/// adopted them before publishes nothing. `Records` are the raw bytes, or
/// null when the release kept none.
public sealed record AdoptWindowRecords(byte[]? Records) : WindowIntent;

/// Closes a window. A saved window's record stays for the next launch; a
/// window that is not saved is gone. Closing a window that is not open
/// publishes nothing.
public sealed record CloseWindow(Guid WindowId) : WindowIntent;

/// Opens a window over a workspace attached to this device. A saved window
/// keeps its record in the device store across launches, and only a window
/// over the persistent session may be saved. A saved window with a record
/// shows what the record shows. A window without a record starts as
/// `CopyingWindowId` shows, or on the launch Space. When `RestoresTabs` is
/// false it keeps only that Space and shows no tab until one is chosen.
/// `ShowingTabs` then name the tab it shows in those Spaces, and
/// `ShowingSpaceId` the Space it opens on, keeping what it shows there.
/// Opening a window that is already open answers what it shows.
public sealed record OpenWindow(Guid WindowId, Guid WorkspaceId, bool Saved, Guid? CopyingWindowId, Guid? ShowingSpaceId,
    IReadOnlyList<ShownTab> ShowingTabs, bool RestoresTabs) : WindowIntent;

/// Records the share of the width each column of a split group takes in one
/// window. Shares that drift from summing to one are normalized; a list that
/// cannot describe columns is refused with `InvalidSplitColumnShares`.
public sealed record ResizeSplitColumns(Guid WindowId, Guid GroupId, IReadOnlyList<double> Shares) : WindowIntent;

#endregion

#region Intents - Spaces

/// Shows the Space before or after the one a window shows, among the Spaces it
/// may show in the session's order, which leaves out one being deleted,
/// wrapping at both ends, as `ShowSpace` shows it. Publishes nothing when the
/// window may show fewer than two Spaces.
public sealed record ShowAdjacentSpace(Guid WindowId, AdjacentDirection Direction) : WindowIntent;

/// Shows a Space in a window, on the tab the window last showed there while
/// it still exists, or else on the Space's fallback tab. A Space that is gone
/// or being deleted publishes nothing.
public sealed record ShowSpace(Guid WindowId, Guid SpaceId) : WindowIntent;

#endregion

#region Intents - Tabs

/// Stops a window showing a tab the session keeps, such as a saved page it
/// closes without closing the tab: the window shows the tab it showed before
/// in that Space, recording its use, or nothing. A window that no longer
/// shows the tab publishes nothing.
public sealed record DismissShownTab(Guid WindowId, Guid SpaceId, Guid TabId) : WindowIntent;

/// Shows the tab one stop from the one a window shows, in the order its Space's
/// sidebar shows them (see `SidebarOutline.Stops`), wrapping at both ends. A
/// split is one stop, and stepping onto it shows its first tab. A shown tab the
/// sidebar hides in a collapsed folder or section steps from where it lives
/// there, and a shown Start Page from the ends. Records the tab's use as
/// `ShowTab` does. Publishes nothing when the window shows no tab, the Space
/// shows no stops, or the step leads back to the stop it shows.
public sealed record ShowAdjacentTab(Guid WindowId, AdjacentDirection Direction) : WindowIntent;

/// Shows the tab of the window's Space used most recently other than the one
/// it shows, recording its use as `ShowTab` does. Publishes nothing when the
/// window shows no tab or the Space holds no other.
public sealed record ShowMostRecentTab(Guid WindowId) : WindowIntent;

/// Shows a tab in a window, switching the window to the tab's Space, and
/// records when the tab was last used, which current-tab cleanup reads. A
/// null tab leaves the Space showing nothing and the window where it is. A
/// Space or tab that is already gone publishes nothing.
public sealed record ShowTab(Guid WindowId, Guid SpaceId, Guid? TabId) : WindowIntent;

#endregion

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
