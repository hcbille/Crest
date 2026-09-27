using CrestCore.Application;

namespace CrestCore.Contracts;

/// The engine's page is gone: the core asked the engine to close it, or the
/// page closed itself, as `window.close()` does. A page closed keeping its
/// state hands back what brings it back, when its engine can.
public sealed record PageClosed(Guid PageId, PageRestoreState? RestoreState) : PageEvent(PageId) {
    #region Actions - Pages

    /// What a page closed keeping its state hands back goes to its tab, though
    /// the core let the page go when it asked the engine to close it.
    internal override void Apply(Pages pages, Engine engine, PageTurn turn) {
        pages.KeepRestoreState(PageId, engine, RestoreState);
        base.Apply(pages, engine, turn);
    }

    internal override void Apply(Pages pages, Page page, PageTurn turn) => pages.Enter(page, PagePhase.Closed, turn.Changes);

    #endregion
}
