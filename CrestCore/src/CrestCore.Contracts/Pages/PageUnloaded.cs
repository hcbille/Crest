namespace CrestCore.Contracts;

/// The core unloaded a page to give memory back. The tab keeps its place, and
/// its next page restores what this one showed. The page is gone, as
/// `PageRemoved` also says.
public sealed record PageUnloaded(Guid PageId, Guid WorkspaceId, Guid TabId) : Change;
