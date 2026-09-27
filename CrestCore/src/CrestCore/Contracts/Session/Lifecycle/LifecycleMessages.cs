namespace CrestCore.Contracts;

#region Intents

/// Archives every open tab of a Space and keeps its saved and pinned tabs.
/// The window that asked shows the tab its Space falls back to. Refused with
/// `NoCurrentTabs` when the Space has no open tab.
public sealed record ClearCurrentTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId) : SessionIntent(WorkspaceId);

/// Closes a tab the way its section closes one: an open tab is archived, and
/// a saved or pinned tab keeps its place and only puts its page away, back at
/// its saved address when the app's preferences say so. A window that showed
/// the tab returns to the tab it showed before. Refused with `LastStartPage`
/// for the Start Page when it is its Space's only tab, which leaves only the
/// window to close.
public sealed record CloseTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);

/// Deletes a tab from any section and keeps it in the archive as an open tab.
/// The window that asked returns to the tab it showed before, or to the tab
/// its Space falls back to.
public sealed record DeleteTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);

/// Copies a tab into `Placement`'s section, or among the open tabs when null,
/// with an identity the core gives it, published as `TabCopied`. A copy of a
/// web page starts from where the source's page is now. When `Shows`, the
/// window that asked shows the copy and its Space.
public sealed record DuplicateTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, TabPlacement? Placement, bool Shows)
    : SessionIntent(WorkspaceId);

/// Moves a tab into `FolderId`, or to the top level of `Placement`'s section,
/// before the tab `BeforeTabId` names or after the section's last tab. A split
/// member moving to a section that holds no splits leaves its split; elsewhere
/// it keeps it unless `LeavesSplit` takes it out. Refused with
/// `PinnedTabsFull` for a full section, and `UnknownFolder` or
/// `InvalidFolderPlacement` for a folder that is not there or not in the
/// section.
public sealed record MoveTab(Guid WorkspaceId, Guid SpaceId, Guid TabId, TabPlacement Placement, Guid? FolderId, Guid? BeforeTabId,
    bool LeavesSplit) : SessionIntent(WorkspaceId);

/// Opens `Address` for the window that asked, in a Space it shows: a Start Page
/// the window shows there takes the address, as `NavigateTab` gives one, and
/// otherwise a new tab, `TabId`, opens it after the tab the window shows. The
/// window shows the tab either way. Refused as `NavigateTab` and `OpenTab`
/// refuse.
public sealed record OpenAddress(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, string Address)
    : SessionIntent(WorkspaceId);

/// Opens a tab, `TabId`, showing `Content` in `Placement`'s section of a
/// Space: after the tab `AfterTabId` names and outside its split, or where its
/// section puts a new tab. When `Shows`, the window that asked shows the tab
/// and its Space. Refused with `TabLimitReached` or `PinnedTabsFull` when the
/// Space or the section is full, and with `UnsupportedAddress` for an address
/// a page cannot load.
public sealed record OpenTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, TabContent Content, TabPlacement Placement,
    Guid? AfterTabId, bool Shows) : SessionIntent(WorkspaceId);

/// What a new tab shows: the page at `Address`, the native view `View`, or,
/// with neither, the Start Page. `Title` names a page until it loads and
/// reports its own; a page without one is titled by its host. A native view
/// titles and draws its tab itself.
public sealed record TabContent(string? Address, NativeView? View, string? Title);

/// Shows a Start Page in a Space: the window that asked shows the Space's first
/// open Start Page, or, when `OutsideSplits`, its first one in no split; when
/// the Space has none, a new one, `TabId`, opens after the tab the window
/// shows there. A window returning to a Space asks for one outside splits, so
/// it never lands on half of a split.
public sealed record ShowStartPage(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, bool OutsideSplits)
    : SessionIntent(WorkspaceId);

/// Pins a tab at the end of the pinned tabs, out of its split, or returns a
/// pinned tab to the end of the open tabs. Refused as `MoveTab` refuses,
/// with `PinnedTabsFull` when no tab more fits among the pinned.
public sealed record TogglePin(Guid WorkspaceId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);

#endregion

#region Rejections

/// The tab is in a split, and the section it would move to holds no splits,
/// so it moves only by leaving its split.
public sealed record CannotPinSplit(Guid TabId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Split View groups cannot be pinned. Separate the split first.";

    #endregion
}

/// The tab shows the Start Page and is its Space's only tab, so closing it
/// leaves nothing but its window to close.
public sealed record LastStartPage(Guid TabId) : Rejection;

/// The Space has no open tab to clear.
public sealed record NoCurrentTabs(Guid SpaceId) : Rejection;

/// The Space already pins `Capacity` tabs, so it pins no more.
public sealed record PinnedTabsFull(int Capacity) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized(Argument = nameof(Capacity))]
    public string Message => "A Space can hold up to %lld pinned tabs. Unpin tabs or select fewer tabs.";

    #endregion
}

/// The tab shows the Start Page, which has nothing to copy.
public sealed record StartPageNotCopied(Guid TabId) : Rejection;

#endregion
