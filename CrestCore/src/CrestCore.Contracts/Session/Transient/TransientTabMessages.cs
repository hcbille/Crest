namespace CrestCore.Contracts;

#region Intents

/// Keeps a Quick Window's page, `PageId`, in its Space's archive as a closed
/// open tab at the address and title it shows, so it can be found again. The
/// page may already be gone, as one memory pressure took back is; the core
/// keeps what it showed last. A page still open must live in `SpaceId`.
/// Refused when the page was already kept or archived, when it lives in
/// another Space, when the core no longer knows it, and when the Space is
/// locked or being deleted.
public sealed record ArchiveTransientPage(Guid WorkspaceId, Guid PageId, Guid SpaceId) : SessionIntent(WorkspaceId);

/// Keeps a Quick Window's or Peek's page, `PageId`, as a new tab of a Space
/// in `Placement`'s section, after the tab the window that asked shows there.
/// The core gives the tab its identity and the address the page shows, and
/// that window shows it and its Space. The tab takes the page itself when the
/// page's engine can move it between windows and the page already lives in
/// that Space; the core says which in `TransientPagePromoted`. Refused when
/// the page was already kept or archived, when its own Space no longer keeps
/// its profile, and when either Space is locked or being deleted.
public sealed record PromoteTransientPage(Guid WorkspaceId, Guid WindowId, Guid PageId, Guid SpaceId, TabPlacement Placement)
    : SessionIntent(WorkspaceId);

#endregion

#region Rejections

/// The Quick Window's or Peek's page was already kept as a tab or archived,
/// so it is not kept again.
public sealed record TransientAlreadyCompleted(Guid PageId) : Rejection;

#endregion
