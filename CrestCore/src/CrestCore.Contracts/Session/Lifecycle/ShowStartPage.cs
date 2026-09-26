namespace CrestCore.Contracts;

/// Shows a Start Page in a Space: the window that asked shows the Space's first
/// open Start Page, or, when `OutsideSplits`, its first one in no split; when
/// the Space has none, a new one, `TabId`, opens after the tab the window
/// shows there. A window returning to a Space asks for one outside splits, so
/// it never lands on half of a split.
public sealed record ShowStartPage(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, bool OutsideSplits)
    : SessionIntent(WorkspaceId);
