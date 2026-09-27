using CrestCore.Contracts;

namespace CrestCore.Application;

internal sealed partial class Pages {
    #region Actions - Staged links

    /// A page's first load runs the link its source page's engine staged, so
    /// the link keeps its referrer, initiator and security. Only a page on the
    /// same engine and profile as its source that has loaded nothing yet can
    /// take the link, whether or not its engine created it already; the
    /// engine checks the link still applies when the page loads.
    public void Handle(StageLink intent, PageTurn turn) {
        var page = Known(intent.PageId);
        var source = Known(intent.SourcePageId);
        if (!ReferenceEquals(page.Engine, source.Engine) || page.ProfileId != source.ProfileId || !page.AwaitsFirstLoad)
            throw new Rejected(new StagedLinkElsewhere(page.Id, source.Id));
        turn.Issue(page.Engine, new StageNavigation(page.Id, intent.StagedLinkId, intent.Url));
    }

    /// No page will load a staged link, so the engine of the page it was
    /// followed in forgets it. A source page that is gone took its links with it.
    public void Handle(DiscardStagedLink intent, PageTurn turn) {
        if (open.GetValueOrDefault(intent.SourcePageId) is { } source)
            turn.Issue(source.Engine, new DropStagedLink(intent.StagedLinkId));
    }

    #endregion
}
