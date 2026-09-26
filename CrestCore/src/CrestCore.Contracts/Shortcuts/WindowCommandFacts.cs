namespace CrestCore.Contracts;

/// What a window shows, as the commands that act on it read it: whether it
/// shows a Space, in a private workspace or not, the tab it shows there, and
/// what that Space and tab allow. Commands carry their own rule over these
/// facts; see `ShortcutCommand.IsAvailable`.
public sealed record WindowCommandFacts(bool ShowsSpace, bool IsPrivate, TabState? ShownTab, bool HasArchivedTabs,
    bool HasSplitCandidate, int CardCount);
