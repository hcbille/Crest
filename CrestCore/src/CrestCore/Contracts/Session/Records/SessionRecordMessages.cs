namespace CrestCore.Contracts;

#region Intents

/// Moves the open tabs of a Space that went unused for longer than its
/// cleanup lifetime to its archive, keeping every tab a window shows or a
/// saved window will show. Without a Space it cleans up every Space that is
/// not being deleted, locked or not, since cleanup reveals nothing.
public sealed record CleanUpCurrentTabs(Guid WorkspaceId, Guid? SpaceId) : SessionIntent(WorkspaceId);

/// Removes every address a Space's history holds. Without a Space it clears
/// every Space this process may read, passing over one that is locked or being
/// deleted.
public sealed record ClearHistory(Guid WorkspaceId, Guid? SpaceId) : SessionIntent(WorkspaceId);

/// Removes the history entry for one address from a Space. The address is
/// compared the way history records it, without its fragment, so an address
/// history never records removes nothing.
public sealed record RemoveHistoryAddress(Guid WorkspaceId, Guid SpaceId, string Address) : SessionIntent(WorkspaceId);

/// Removes the history entries of a Space last visited from `Start` up to,
/// but not including, `End`. A range that ends before it starts is refused
/// with `InvalidDateRange`.
public sealed record RemoveHistoryRange(Guid WorkspaceId, Guid SpaceId, DateTimeOffset Start, DateTimeOffset End)
    : SessionIntent(WorkspaceId);

/// Reopens the tab the Space archived last, as `RestoreArchivedTab` reopens
/// one, and the window that asked shows it. Refused with `NoArchivedTabs` when
/// the Space keeps none.
public sealed record ReopenClosedTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId) : SessionIntent(WorkspaceId);

/// Reopens an archived tab as an open tab of its Space and removes its entry
/// from the archive. The window that asked shows it, when that window is open
/// over the workspace.
public sealed record RestoreArchivedTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);

/// Applies every Space's retention: open tabs unused for longer than the
/// Space's cleanup lifetime move to its archive, and history and archive
/// entries older than the Space keeps them are removed. A tab a window shows,
/// or a saved window will show, stays open. Locked Spaces are swept too, since
/// a sweep reveals nothing; Spaces being deleted are not.
///
/// Every window of a workspace asks for sweeps, so a sweep less than a minute
/// after the last one does nothing, unless a Space's retention changed since.
public sealed record SweepExpiredRecords(Guid WorkspaceId) : SessionIntent(WorkspaceId);

#endregion

#region Rejections

/// The range ends before it starts.
public sealed record InvalidDateRange : Rejection;

/// The Space keeps no archived tab to reopen.
public sealed record NoArchivedTabs(Guid SpaceId) : Rejection;

/// The Space's archive holds no tab with this identity.
public sealed record UnknownArchivedTab(Guid TabId) : Rejection;

#endregion
