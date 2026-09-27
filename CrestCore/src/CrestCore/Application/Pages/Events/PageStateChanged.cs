using CrestCore.Application;

namespace CrestCore.Contracts;

/// What a page's engine shows changed. A binding reports a page's latest
/// snapshot at most once per turn, and only when it differs from the last one
/// it reported.
public sealed record PageStateChanged(Guid PageId, PageSnapshot Snapshot) : PageEvent(PageId) {
    #region Actions - Pages

    internal override void Apply(Pages pages, Page page, PageTurn turn) => pages.Update(page, turn.Changes, () => page.Show(Snapshot));

    #endregion
}
