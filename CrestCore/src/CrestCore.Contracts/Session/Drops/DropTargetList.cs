namespace CrestCore.Contracts;

/// Where a lift may drop. `Refusal` is the rule that refuses the lift itself,
/// such as `SelectionChanged` or `PinnedTabsDragAlone`, which leaves every list
/// empty. Otherwise `Lists` holds every list of the Space's sidebar, sections
/// first and then each folder's inside; `SpaceIds` every other Space the window
/// may show; `Split` the cards the window shows, with the rule that refuses
/// joining them, or null when it shows no tab; and `FolderAroundTabIds` the
/// open tabs a new folder may be made around, in sidebar order. Whether a drop
/// lands in a list or on a Space is asked of that drop, once the lift reaches
/// it, so a lift pays only for the targets it visits.
public sealed record DropTargetList(Rejection? Refusal, IReadOnlyList<ListDropTarget> Lists, IReadOnlyList<Guid> SpaceIds,
    SplitDropTarget? Split, IReadOnlyList<Guid> FolderAroundTabIds);
