using CrestCore.Contracts;

namespace CrestCore.Application;

/// A page's back and forward history as its engine last reported it: the
/// entries, oldest first, and the one the page shows. The core reads it for
/// whether the page can go back or forward, for the history menus, and for
/// the entry a step through history reaches, so every input asks the same
/// list the menus show. The engine's report always wins: the core never
/// guesses at an entry the engine has not reported.
internal sealed record PageHistory(IReadOnlyList<PageHistoryEntry> Entries, int Current) {
    #region Static Variables

    /// The most entries a page's history holds, as WebKit keeps them.
    public const int Capacity = 100;

    /// A page whose engine has reported no history yet.
    public static PageHistory Empty { get; } = new([], Current: -1);

    #endregion

    #region Variables

    public bool CanGoBack => Current > 0;
    public bool CanGoForward => Current >= 0 && Current < Entries.Count - 1;

    /// The entries the page can go back to, nearest first.
    public IReadOnlyList<PageHistoryEntry> Back => [.. Entries.Take(Math.Max(Current, 0)).Reverse()];

    /// The entries the page can go forward to, nearest first.
    public IReadOnlyList<PageHistoryEntry> Forward => [.. Entries.Skip(Current + 1)];

    #endregion

    #region Constructors

    /// The history an engine reported, or null for one no engine could hold:
    /// more entries than `Capacity`, an entry twice, or a current entry
    /// outside the list. Only an empty history has no current entry.
    public static PageHistory? Reported(IReadOnlyList<PageHistoryEntry> entries, int current) {
        bool fits = entries.Count == 0 ? current == -1 : current >= 0 && current < entries.Count;
        if (!fits || entries.Count > Capacity || entries.Select(entry => entry.Id).Distinct().Count() != entries.Count) return null;
        return new(entries, current);
    }

    #endregion

    #region Actions - Traversal

    /// The entry `offset` steps from the current one, back when negative, or
    /// null when the history has none there.
    public PageHistoryEntry? Step(int offset) {
        int index = Current + offset;
        return offset != 0 && Current >= 0 && index >= 0 && index < Entries.Count ? Entries[index] : null;
    }

    /// Whether the history holds the entry `entryId` names, other than the
    /// current one.
    public bool Reaches(Guid entryId) =>
        Entries.Where((entry, index) => index != Current).Any(entry => entry.Id == entryId);

    #endregion

    #region Actions - Equality

    public bool Equals(PageHistory? other) =>
        other is not null && Current == other.Current && Entries.SequenceEqual(other.Entries);

    public override int GetHashCode() => HashCode.Combine(Current, Entries.Count);

    #endregion
}
