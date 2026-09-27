namespace CrestCore.Contracts;

#region Intents

/// Archives the open tabs a person selected in a window. The window then shows
/// the tab it showed before, when the one it showed was archived, or none.
/// Refused with `CurrentTabsOnly` for a saved or pinned tab, which closes only
/// on its own, and by the rules every selection answers to: see
/// `SelectionChanged`, `IncompleteSplit` and `SelectionHoldsFolders`.
public sealed record CloseTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection) : SessionIntent(WorkspaceId);

/// Deletes the tabs a person selected in a window, saved and pinned ones
/// included, into the archive as open tabs. The window then shows the tab it
/// showed before, when the one it showed was deleted, or none. It is saved
/// with the sync journal, as a deletion, before the intent returns.
public sealed record DeleteTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection) : SessionIntent(WorkspaceId);

/// Copies the tabs a person selected in a window to the end of the open tabs,
/// in the order the sidebar lists them, with identities the core gives them,
/// each published as `TabCopied`. A copy of a web page starts from where its
/// source's page is now, preferring the page the window shows. The copies of a
/// split's members form a split of their own, named, drawn and tinted as the
/// source split is.
public sealed record DuplicateTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection) : SessionIntent(WorkspaceId);

/// Puts the tabs and folders a person selected in a window into a new folder
/// the core makes at the top level of `Placement`'s section, named "New
/// Folder" in the default folder color. A selected folder moves in whole, as a
/// folder of the new one. Refused with `InvalidFolderPlacement` for a section
/// that holds no folders.
public sealed record FolderTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, TabPlacement Placement)
    : SessionIntent(WorkspaceId);

/// Puts the tab `TabId` and the tabs a person selected in a window into a new
/// open-tabs folder the core makes in that tab's place, named "New Folder" in
/// the default folder color, holding that tab first. Refused with
/// `InvalidFolderPlacement` when `TabId` is not an open tab at the top level,
/// or is in a split or the selection, or is a Start Page.
public sealed record FolderTabsAround(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, Guid TabId)
    : SessionIntent(WorkspaceId);

/// Keeps the pages of the tabs a person selected in a window loaded while they
/// are not shown, or lets them unload again when `Keeps` is false. A selected
/// folder's tabs are included. Refused with `WebPagesOnly` for a tab that shows
/// no web page.
public sealed record KeepTabsLoaded(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, bool Keeps)
    : SessionIntent(WorkspaceId);

/// Moves the tabs a person selected in a window to the Space
/// `DestinationSpaceId`, each to the end of its own section there, in the
/// order the sidebar lists them. The window then shows the tab it showed
/// before in the Space they left, when the one it showed moved. When `Follows`,
/// it moves to the destination and shows the tab it showed when that moved, or
/// else the first moved tab. Refused with `AlreadyInSpace` for the Space they
/// are in, `CannotMoveSplitAcrossSpaces` for a split member, and
/// `PinnedTabsFull` when the destination cannot hold them all.
public sealed record MoveTabsToSpace(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, Guid DestinationSpaceId,
    bool Follows) : SessionIntent(WorkspaceId);

/// Dissolves every split the tabs a person selected in a window belong to.
public sealed record SeparateSplits(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection) : SessionIntent(WorkspaceId);

/// Combines the tabs a person selected in a window in one split: each joins
/// the split of `TargetTabId`, or of the first selected tab, at member `Index`
/// and on, or after the others. A saved or pinned tab stays where it is and an
/// open copy joins in its place, starting from where its source's page is now,
/// published as `TabCopied`. The window shows the last tab that joined.
/// Refused with `SplitNeedsTwoTabs` or `SplitLimitReached` when the split would
/// hold fewer than two tabs or more than it can.
public sealed record SplitTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, Guid? TargetTabId, int? Index)
    : SessionIntent(WorkspaceId);

#endregion

#region Queries

/// What the tabs and folders a person picked in a Space's sidebar hold, as a
/// window shows it before it acts on them: the picks no picked folder holds, in
/// sidebar order, and every tab and folder they hold. A pick the Space does not
/// hold, and a Start Page, which the sidebar lists nowhere, are left out. A
/// preview reads a locked Space as a person sees it; only an action refuses it.
public sealed record SelectionPreview(Guid WorkspaceId, Guid SpaceId, IReadOnlyList<Guid> TabIds, IReadOnlyList<Guid> FolderIds)
    : Query<SelectedTabs>;

/// A selection previewed in the Space it was made in. `Selection` is what the
/// actions on it take: its roots by kind, holding `Members` as the window saw
/// them. `Roots` are the picks no picked folder holds, in sidebar order;
/// `Members` every tab the selection holds, in sidebar order; `FolderIds` the
/// picked folders and every folder inside them, in sidebar order.
public sealed record SelectedTabs(TabSelection Selection, IReadOnlyList<SelectedRoot> Roots, IReadOnlyList<SelectedTab> Members,
    IReadOnlyList<Guid> FolderIds);

/// A pick no picked folder holds: a tab, or a folder with everything in it.
public sealed record SelectedRoot(Guid Id, SidebarRowKind Kind);

/// A tab a selection holds, with where it lives.
public sealed record SelectedTab(Guid Id, TabPlacement Placement, Guid? FolderId, Guid? SplitGroupId);

#endregion

#region Rejections

/// The tabs would move to the Space `SpaceId`, which already holds them.
public sealed record AlreadyInSpace(Guid SpaceId) : Rejection;

/// The tab is in a split, and a split stays in its Space.
public sealed record CannotMoveSplitAcrossSpaces(Guid TabId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Split View groups stay in their Space. Separate the split before moving it to another Space.";

    #endregion
}

/// The tab is saved or pinned, and only open tabs are archived together.
public sealed record CurrentTabsOnly(Guid TabId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message =>
        "Archive applies to current tabs. Use Unload Pages to close saved or pinned pages, or Delete Tabs to remove their saved entries.";

    #endregion
}

/// The selection holds some members of the split `GroupId` and not the rest.
public sealed record IncompleteSplit(Guid GroupId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "The split changed. Select the whole group again.";

    #endregion
}

/// The selection is not what the window saw: the window no longer shows its
/// Space, or a selected tab or folder is gone, or its folders hold other tabs.
public sealed record SelectionChanged : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "The selected items changed. Select them again before continuing.";

    #endregion
}

/// The selection holds folders, which only filing and keeping pages loaded act on.
public sealed record SelectionHoldsFolders : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message =>
        "Move selected folders into saved or current tabs, or another folder. Use a folder’s own menu for other folder actions.";

    #endregion
}

/// The split would hold one tab, and a split holds two to `Limit` tabs.
public sealed record SplitNeedsTwoTabs(int Limit) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized(Argument = nameof(Limit))]
    public string Message => "Split View needs 2 to %lld tabs. Select fewer tabs or use a smaller split.";

    #endregion
}

#endregion

#region Models

/// The tabs and folders a person selected together in a window's sidebar.
/// `TabIds` and `FolderIds` name what they picked; a tab or folder inside a
/// picked folder goes with that folder. `MemberTabIds` are the tabs the window
/// saw the selection hold when the person acted: each picked tab and every tab
/// inside a picked folder. The core refuses a selection that no longer holds
/// exactly those tabs, and acts on it in the order the Space's sidebar lists
/// it, whatever order the lists name it in.
public sealed record TabSelection(IReadOnlyList<Guid> TabIds, IReadOnlyList<Guid> FolderIds, IReadOnlyList<Guid> MemberTabIds);

#endregion
