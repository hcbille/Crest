namespace CrestCore.Contracts;

#region Intents

/// Moves a tab to the Space `DestinationSpaceId`: into `FolderId` or to the
/// top level of `Placement`'s section there, or of the section it is in,
/// before the tab `BeforeTabId` or after the section's last tab. A split
/// member leaves its split. The window that asked shows the tab it showed
/// before in the Space the tab left, when it showed the moved one; when
/// `Follows`, it moves to the destination and shows the moved tab. Saved with
/// the sync journal before the intent returns. Refused with `AlreadyInSpace`
/// for the Space the tab is in, with `TabLimitReached` or `PinnedTabsFull`
/// when the destination has no room, and with `UnknownFolder` or
/// `InvalidFolderPlacement` for a folder that is not there or not in the
/// section.
public sealed record MoveTabToSpace(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, Guid DestinationSpaceId,
    TabPlacement? Placement, Guid? FolderId, Guid? BeforeTabId, bool Follows) : SessionIntent(WorkspaceId);

/// Moves a tab from the window `WindowId` to the window
/// `DestinationWindowId`, which then shows it in its Space.
///
/// When both windows show this workspace the tab stays where it is. When the
/// destination shows another workspace, one that borrows this one's Space or
/// whose Space this one borrows, the tab leaves this workspace and joins that
/// one's open tabs after the tab its window shows. Both workspaces change
/// together, the one that keeps a file saved with its sync journal before the
/// intent returns, or neither changes; the window the tab left shows the tab
/// it showed before. Refused with `WindowNotOpen` for a destination window
/// that is gone, `PrivateWorkspaceBoundary` between private and other
/// browsing, `UnrelatedWorkspaces` for workspaces that share no Space,
/// `UnknownSpace` when the destination does not hold the tab's Space,
/// `TabAlreadyExists` when it holds the tab, and `TabLimitReached`.
public sealed record MoveTabToWindow(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, Guid DestinationWindowId)
    : SessionIntent(WorkspaceId);

#endregion

#region Rejections

/// The tab would cross between private browsing and other browsing, which
/// share nothing.
public sealed record PrivateWorkspaceBoundary(Guid DestinationWorkspaceId) : Rejection;

/// Neither workspace borrows the other's Spaces, and they borrow from no
/// workspace in common, so no tab moves between them.
public sealed record UnrelatedWorkspaces(Guid DestinationWorkspaceId) : Rejection;

#endregion
