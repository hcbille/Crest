using CrestCore.Contracts;

namespace CrestCore.Application;

/// A date in a property list: seconds since 2001.
internal readonly record struct PropertyListDate(double ReferenceSeconds);

/// A folder of another browser's session, with the identities that browser
/// spells for it and its parent.
internal sealed record SessionFolder(string SourceId, string Title, string? ParentSourceId);

/// A tab of another browser's session: the page it shows, where it sits, the
/// folder it sits in, and when it was last active, where the browser knows.
internal sealed record SessionTab(string Title, ImportAddress Address, TabPlacement Placement, string? FolderSourceId,
    DateTimeOffset? LastActivatedAt);
