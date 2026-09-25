namespace CrestCore.Contracts;

/// The entries the page can go back and forward to, nearest first, for the
/// back and forward menus.
public sealed record PageHistoryChanged(Guid PageId, IReadOnlyList<PageHistoryEntry> Back,
    IReadOnlyList<PageHistoryEntry> Forward) : EnginePresentation;
