namespace CrestCore.Contracts;

/// One list of a Space's sidebar a lift may drop into: the inside of
/// `FolderId`, or the top level of `Section`. Whether a drop lands there is
/// asked of the drop itself, as `CanSend` asks any intent.
public sealed record ListDropTarget(TabPlacement Section, Guid? FolderId);
