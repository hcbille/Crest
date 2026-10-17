using CrestCore.Application;

namespace CrestCore.Contracts;

/// A page's back and forward history changed: its entries, oldest first, and
/// the index of the one it shows, or -1 for a page that holds none. A binding
/// reports it with the page's state, at most once per turn and only when it
/// differs from the last it reported. A history no engine could hold changes
/// nothing.
public sealed record PageHistoryReported(Guid PageId, IReadOnlyList<PageHistoryEntry> Entries, int Current)
    : PageEvent(PageId) {
    #region Actions - Pages

    internal override void Apply(Pages pages, Page page, PageTurn turn) {
        if (PageHistory.Reported(Entries, Current) is { } history) pages.Update(page, turn.Changes, () => page.Record(history));
    }

    #endregion
}
