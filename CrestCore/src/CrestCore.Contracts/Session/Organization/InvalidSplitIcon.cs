namespace CrestCore.Contracts;

/// The icon given for the split is no emoji: its first character does not
/// present as one.
public sealed record InvalidSplitIcon(Guid GroupId) : Rejection;
