namespace CrestCore.Contracts;

/// The core adopted a page its engine opened by itself as the page `PageId`
/// names, owned by the tab `TabId` it opened in `SpaceId` of the workspace
/// `WorkspaceId`. The window `WindowId` names hosts the page, and shows the
/// tab when `Shows`.
public sealed record OfferedPageAdopted(Guid PageId, Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, bool Shows)
    : Change;
