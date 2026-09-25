namespace CrestCore.Contracts;

/// One entry of a page's history: its address and the title it had.
public sealed record PageHistoryEntry(string Url, string Title);
