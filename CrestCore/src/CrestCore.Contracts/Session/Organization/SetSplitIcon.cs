namespace CrestCore.Contracts;

/// Gives a split of two or more tabs an emoji icon: the first character of
/// `Emoji`, given as the emoji or spelled as a symbol. Null clears it. Refused
/// with `InvalidSplitIcon` when that character does not present as an emoji.
public sealed record SetSplitIcon(Guid WorkspaceId, Guid SpaceId, Guid GroupId, string? Emoji) : SessionIntent(WorkspaceId);
