namespace CrestCore.Contracts;

/// How many of a browser's saved passwords belong with the imported Space
/// `SourceSpaceId`, as the platform routes them.
public sealed record ImportPasswordCount(Guid SourceSpaceId, int Count);
