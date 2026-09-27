namespace CrestCore.Contracts;

#region Intents

/// Drops what a person lifted in a window's sidebar, the tabs and folders
/// `Selection` holds as the window saw them, in the Space the window shows.
/// The core commits a drop as the edit its kind names, and decides which in
/// one place: a lift of one tab moves that tab alone, leaving its split, as
/// dragging a tab always has; any other lift acts on the selection whole, as
/// the batch intents do, and a split member brings its split along. Refused
/// with the rule of the edit it commits, and for a lift of pinned tabs with
/// others, `PinnedTabsDragAlone`. `DropTargets` answers, as the lift begins,
/// which drops each target takes.
public abstract record SidebarDrop(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection) : SessionIntent(WorkspaceId);

/// Drops the lift on the open tab `TabId`, putting that tab and then the lift
/// into a new open-tabs folder in its place, named "New Folder" in the default
/// folder color. One tab goes in as `CreateFolder` puts it, leaving its split;
/// any other lift as `FolderTabsAround` does. Refused with
/// `InvalidFolderPlacement` when `TabId` is not an open tab at the top level,
/// or is in a split or the lift, or is a Start Page.
public sealed record DropAroundTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, Guid TabId)
    : SidebarDrop(WorkspaceId, WindowId, SpaceId, Selection);

/// Drops the lift into one list of the Space's sidebar: the inside of
/// `FolderId`, or the top level of `Section`, before the tab `BeforeTabId` or
/// the folder `BeforeFolderId`, or at its end. Onto a collapsed folder's row is
/// at the end of its inside. One tab moves as `FileTabs` moves it, or among the
/// pinned tabs as `MoveTab` does; any other lift is filed as `FileTabs` files
/// it. Refused with `PinsOneTabAtATime` for a lift that is not only pinned tabs
/// dropped among the pinned tabs.
public sealed record DropIntoList(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, TabPlacement Section,
    Guid? FolderId, Guid? BeforeTabId, Guid? BeforeFolderId) : SidebarDrop(WorkspaceId, WindowId, SpaceId, Selection);

/// Drops the lift on the cards a window shows, joining the split of
/// `TargetTabId`, the tab it shows, as the card at `Index` or after the others.
/// One tab joins as `JoinSplit` joins it; any other lift as `SplitTabs` joins
/// it. Refused with `PinnedTabsStayPut` for a lift of several pinned tabs.
public sealed record DropIntoSplit(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, Guid TargetTabId, int? Index)
    : SidebarDrop(WorkspaceId, WindowId, SpaceId, Selection);

/// Drops the lift on another Space of the workspace, to the end of each tab's
/// own section there, and the window follows it when `Follows`. One tab moves
/// as `MoveTabToSpace` moves it; any other lift as `MoveTabsToSpace` moves it.
/// Refused with `PinnedTabsStayPut` for a lift of several pinned tabs.
public sealed record DropOnSpace(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, Guid DestinationSpaceId,
    bool Follows) : SidebarDrop(WorkspaceId, WindowId, SpaceId, Selection);

#endregion

#region Queries

/// Where a lift of `Selection` in a window's sidebar may drop, answered once as
/// the lift begins: the rule that refuses the lift, the lists and Spaces it may
/// reach, and whether it may join the cards on show. Each list or Space drop is
/// checked as the lift reaches it. A drop may still be refused when it lands,
/// since the session can change while the lift is held; its commit decides.
public sealed record DropTargets(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection) : Query<DropTargetList>;

/// Where a lift may drop. `Refusal` is the rule that refuses the lift itself,
/// such as `SelectionChanged` or `PinnedTabsDragAlone`, which leaves every list
/// empty. Otherwise `Lists` holds every list of the Space's sidebar, sections
/// first and then each folder's inside; `SpaceIds` every other Space the window
/// may show; `Split` the cards the window shows, with the rule that refuses
/// joining them, or null when it shows no tab; and `FolderAroundTabIds` the
/// open tabs a new folder may be made around, in sidebar order. Whether a drop
/// lands in a list or on a Space is asked of that drop, once the lift reaches
/// it, so a lift pays only for the targets it visits.
public sealed record DropTargetList(Rejection? Refusal, IReadOnlyList<ListDropTarget> Lists, IReadOnlyList<Guid> SpaceIds,
    SplitDropTarget? Split, IReadOnlyList<Guid> FolderAroundTabIds);

/// One list of a Space's sidebar a lift may drop into: the inside of
/// `FolderId`, or the top level of `Section`. Whether a drop lands there is
/// asked of the drop itself, as `CanSend` asks any intent.
public sealed record ListDropTarget(TabPlacement Section, Guid? FolderId);

/// The cards a window shows, the split of `TabId`, the tab it shows, and the
/// rule that refuses a lift joining them, or null when it may.
public sealed record SplitDropTarget(Guid TabId, Rejection? Refusal);

#endregion

#region Rejections

/// The lift holds pinned tabs with saved or open tabs or folders, which move
/// apart.
public sealed record PinnedTabsDragAlone : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Pinned tabs cannot join a drag with saved or current tabs. Start the drag again.";

    #endregion
}

/// Several pinned tabs would drop on another Space or the cards a window shows,
/// where pinned tabs move one at a time.
public sealed record PinnedTabsStayPut : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Move selected pinned tabs within their pinned area or into saved or current tabs.";

    #endregion
}

/// Several tabs, or a folder, would drop among the pinned tabs, which take tabs
/// one at a time.
public sealed record PinsOneTabAtATime : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Drag one tab at a time to pin it.";

    #endregion
}

#endregion
