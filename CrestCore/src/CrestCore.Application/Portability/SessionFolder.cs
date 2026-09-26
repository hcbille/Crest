namespace CrestCore.Application;

/// A folder of another browser's session, with the identities that browser
/// spells for it and its parent.
internal sealed record SessionFolder(string SourceId, string Title, string? ParentSourceId);
