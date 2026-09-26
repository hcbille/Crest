namespace CrestCore.Contracts;

/// One profile of a browser: `Id`, the name the browser keeps it under, the
/// `Name` the person gave it, and the paths of its bookmarks and of its latest
/// session, where it keeps either. A profile keeps at least one.
public sealed record ImportProfile(string Id, string Name, string? BookmarksPath, string? SessionPath);
