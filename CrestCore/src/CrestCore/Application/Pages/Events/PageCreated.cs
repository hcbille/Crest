using CrestCore.Application;

namespace CrestCore.Contracts;

/// The engine created the page, which is now live.
public sealed record PageCreated(Guid PageId) : PageEvent(PageId) {
    #region Actions - Pages

    /// A page moved to this engine loads the address it showed.
    internal override void Apply(Pages pages, Page page, PageTurn turn) {
        pages.Enter(page, PagePhase.Live, turn.Changes);
        if (page.TakeRehostedAddress() is { } address) turn.Issue(page.Engine, new LoadPage(page.Id, address));
    }

    #endregion
}
