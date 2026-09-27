namespace CrestCore.Contracts;

#region Intents - Folders

/// Collapses a folder in the sidebar, or expands it.
public sealed record CollapseFolder(Guid WorkspaceId, Guid SpaceId, Guid FolderId, bool Collapsed) : SessionIntent(WorkspaceId);

/// Creates a folder in a Space's saved or open section, or inside `ParentId`,
/// whose section it shares. A blank title names it "New Folder". The tabs
/// `TabIds` names move into it in the same edit, so a folder nobody asked to
/// see empty is never published, and one whose tabs cannot move is never made.
/// A split member brings its split along, unless `LeavesSplits` takes it out.
public sealed record CreateFolder(Guid WorkspaceId, Guid SpaceId, Guid FolderId, TabPlacement Placement, Guid? ParentId,
    string? Title, BrandColor? Color, string? Symbol, IReadOnlyList<Guid> TabIds, bool LeavesSplits) : SessionIntent(WorkspaceId);

/// Deletes a folder. Its tabs and folders move up into its parent, or to the
/// top level of its section.
public sealed record DeleteFolder(Guid WorkspaceId, Guid SpaceId, Guid FolderId) : SessionIntent(WorkspaceId);

/// Moves the tabs and folders a person selected in a window into `FolderId`
/// or to the top level of `Placement`'s section, before the tab `BeforeTabId`
/// or the folder `BeforeFolderId` names, in the order the sidebar lists them.
/// A selected folder moves whole, and a split member brings its split along,
/// unless `LeavesSplits` takes it out. In a section that holds no folders,
/// such as the pinned tabs, the tabs move one by one, refused with
/// `CannotPinSplit` for a split member that stays in its split and with
/// `PinnedTabsFull` when the section cannot hold them all. Saved with the sync
/// journal before the intent returns.
public sealed record FileTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection, TabPlacement Placement,
    Guid? FolderId, Guid? BeforeTabId, Guid? BeforeFolderId, bool LeavesSplits) : SessionIntent(WorkspaceId);

/// Moves a folder, with everything inside it, into `ParentId` or to the top
/// level of `Placement`'s section, before `BeforeFolderId` among its new
/// siblings or before the tab `BeforeTabId` names. Without a section or a
/// parent it stays in its own section. A folder never moves into itself.
public sealed record MoveFolder(Guid WorkspaceId, Guid SpaceId, Guid FolderId, TabPlacement? Placement, Guid? ParentId,
    Guid? BeforeFolderId, Guid? BeforeTabId) : SessionIntent(WorkspaceId);

/// Renames a folder. A blank title names it "Untitled Folder".
public sealed record RenameFolder(Guid WorkspaceId, Guid SpaceId, Guid FolderId, string Title) : SessionIntent(WorkspaceId);

/// Gives a folder the color its icon wears.
public sealed record SetFolderColor(Guid WorkspaceId, Guid SpaceId, Guid FolderId, BrandColor Color) : SessionIntent(WorkspaceId);

/// Gives a folder its icon: an SF Symbol name or an emoji.
public sealed record SetFolderSymbol(Guid WorkspaceId, Guid SpaceId, Guid FolderId, string Symbol) : SessionIntent(WorkspaceId);

#endregion

#region Intents - Splits

/// Ends a split. Its tabs stay where they are.
public sealed record DissolveSplit(Guid WorkspaceId, Guid SpaceId, Guid GroupId) : SessionIntent(WorkspaceId);

/// Adds a tab to the split of `TargetTabId`, or makes the two a split, at
/// member `Index` or after the others. A saved or pinned tab stays where it is
/// and an open copy joins in its place, with an identity the core gives it,
/// showing what its source's page shows now; each copy is published as
/// `TabCopied`. The window that asked shows the joined tab in its Space.
public sealed record JoinSplit(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, Guid TargetTabId, int? Index)
    : SessionIntent(WorkspaceId);

/// Takes a tab out of its split, after the split's last member. A split left
/// with one member ends.
public sealed record LeaveSplit(Guid WorkspaceId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);

/// Moves a split's tabs, in order, into `FolderId` or to the top level of
/// `Placement`'s section, before the tab `BeforeTabId` names.
public sealed record MoveSplit(Guid WorkspaceId, Guid SpaceId, Guid GroupId, TabPlacement Placement, Guid? FolderId, Guid? BeforeTabId)
    : SessionIntent(WorkspaceId);

/// Moves a tab to member `Index` of its split, clamped to the split's members.
public sealed record MoveSplitMember(Guid WorkspaceId, Guid SpaceId, Guid TabId, int Index) : SessionIntent(WorkspaceId);

/// Names a split of two or more tabs. A blank or null name clears it.
public sealed record NameSplit(Guid WorkspaceId, Guid SpaceId, Guid GroupId, string? Name) : SessionIntent(WorkspaceId);

/// Opens `Address` as a new open tab, `TabId`, titled `Title`, and joins it to
/// the split of `TargetTabId` as `JoinSplit` does, copies included. The window
/// that asked shows the new tab.
public sealed record OpenLinkInSplit(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, Guid TargetTabId,
    string Address, string Title) : SessionIntent(WorkspaceId);

/// Gives a split of two or more tabs an emoji icon: the first character of
/// `Emoji`, given as the emoji or spelled as a symbol. Null clears it. Refused
/// with `InvalidSplitIcon` when that character does not present as an emoji.
public sealed record SetSplitIcon(Guid WorkspaceId, Guid SpaceId, Guid GroupId, string? Emoji) : SessionIntent(WorkspaceId);

/// Moves a tab `Offset` members along its split. Refused with `NoSplitStep`
/// when the step would move nothing: no offset, a step past either end, or a
/// tab in no split.
public sealed record StepSplitMember(Guid WorkspaceId, Guid SpaceId, Guid TabId, int Offset) : SessionIntent(WorkspaceId);

/// Tints a split of two or more tabs. Null clears the tint.
public sealed record TintSplit(Guid WorkspaceId, Guid SpaceId, Guid GroupId, BrandColor? Tint) : SessionIntent(WorkspaceId);

#endregion

#region Rejections - Folders

/// The Space already holds a folder with this identity.
public sealed record FolderAlreadyExists(Guid FolderId) : Rejection;

/// The folder would move into itself or into one of its own folders.
public sealed record FolderCycle(Guid FolderId) : Rejection;

/// The folder, or the deepest folder inside it, would sit `Limit` levels deep
/// or deeper.
public sealed record FolderDepthLimitReached(int Limit) : Rejection;

/// The Space already holds `Limit` folders.
public sealed record FolderLimitReached(int Limit) : Rejection;

/// The folder or tabs cannot go where the edit places them: the section holds
/// no folders, the folder named to hold them is in another section, or the
/// folder or tab named to go before is elsewhere or moves with them.
public sealed record InvalidFolderPlacement : Rejection;

/// A folder's symbol is an SF Symbol name or an emoji, never empty and never
/// longer than `MaximumBytes` in UTF-8.
public sealed record InvalidFolderSymbol(int MaximumBytes) : Rejection;

/// The Space holds no folder with this identity.
public sealed record UnknownFolder(Guid FolderId) : Rejection;

#endregion

#region Rejections - Splits

/// The tab is already a member of that split.
public sealed record AlreadyInSplit(Guid TabId) : Rejection;

/// The icon given for the split is no emoji: its first character does not
/// present as one.
public sealed record InvalidSplitIcon(Guid GroupId) : Rejection;

/// Stepping the tab `Offset` members along its split would move nothing.
public sealed record NoSplitStep(Guid TabId, int Offset) : Rejection;

/// The tabs would land between two members of a split they do not belong to.
public sealed record SplitBoundary : Rejection;

/// The split already holds `Limit` tabs.
public sealed record SplitLimitReached(int Limit) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized(Argument = nameof(Limit))]
    public string Message => "Split View needs 2 to %lld tabs. Select fewer tabs or use a smaller split.";

    #endregion
}

/// No split in the Space has this identity, or it has fewer than two tabs.
public sealed record UnknownSplitGroup(Guid GroupId) : Rejection;

/// Only a page can join a split or keep its page loaded, and a Start Page or
/// a native view is not one.
public sealed record WebPagesOnly(Guid TabId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This action requires webpage tabs. Deselect built-in pages first.";

    #endregion
}

#endregion
