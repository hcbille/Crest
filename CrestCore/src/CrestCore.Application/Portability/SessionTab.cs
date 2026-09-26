using CrestCore.Contracts;

namespace CrestCore.Application;

/// A tab of another browser's session: the page it shows, where it sits, the
/// folder it sits in, and when it was last active, where the browser knows.
internal sealed record SessionTab(string Title, ImportAddress Address, TabPlacement Placement, string? FolderSourceId,
    DateTimeOffset? LastActivatedAt);
