using CrestCore.Application;

namespace CrestCore.Contracts;

/// A page began navigating to `Url`: a load that will replace its document,
/// or, when `SameDocument`, a move within the document it shows, such as
/// `history.pushState` or a fragment. Nothing is recorded until the
/// navigation finishes.
public sealed record NavigationStarted(Guid PageId, string Url, bool SameDocument) : PageEvent(PageId) {
    #region Actions - Pages

    /// A navigation to another document of a site chosen for another
    /// registered engine moves the page there, which loads it instead.
    internal override void Apply(Pages pages, Page page, PageTurn turn) {
        if (!SameDocument && pages.Shown(page) is { } space && pages.Chosen(space, Url) is { } chosen
            && !ReferenceEquals(chosen, page.Engine))
            pages.Rehost(page, chosen, Url, RehostReason.SiteChoice, turn);
    }

    #endregion
}
