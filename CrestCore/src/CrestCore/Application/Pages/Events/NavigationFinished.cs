using CrestCore.Application;

namespace CrestCore.Contracts;

/// A page's navigation finished at `Url`, titled `Title`, which may be empty.
/// The core records the first finish of each document: the tab that owns the
/// page shows the address and title, and the Space's history holds a visit. A
/// move within the document finishes once its title settles.
public sealed record NavigationFinished(Guid PageId, string Url, string Title) : PageEvent(PageId) {
    #region Actions - Pages

    /// The record waits while a transaction holds the workspace's session.
    internal override void Apply(Pages pages, Page page, PageTurn turn) {
        if (page.Finish(Url))
            pages.Edit(page, new NavigationRecord(page.Id, page.SpaceId, pages.Clock.Now, page.TabId, Url, Title, page.Icon, pages.Ids.Next()),
                turn.Changes);
    }

    #endregion
}
