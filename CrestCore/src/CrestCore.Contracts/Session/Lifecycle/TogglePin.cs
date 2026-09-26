namespace CrestCore.Contracts;

/// Pins a tab at the end of the pinned tabs, out of its split, or returns a
/// pinned tab to the end of the open tabs. Refused as `MoveTab` refuses,
/// with `PinnedTabsFull` when no tab more fits among the pinned.
public sealed record TogglePin(Guid WorkspaceId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);
