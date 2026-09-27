namespace CrestCore.Contracts;

/// The saved or pinned tab `TabId` put its page away, as window `WindowId`
/// asked. The platform that hosts the tab's page for that window lets it go,
/// keeping what brings it back when `KeepsState`; otherwise the tab returned
/// to its saved address and nothing of its page is kept.
public sealed record TabPagePutAway(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, bool KeepsState) : Change;
