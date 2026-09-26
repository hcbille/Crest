using CrestCore.Contracts;

namespace CrestCore.Application;

internal sealed partial class Pages {
    #region Actions - Staged links

    /// A page's first load runs the link its source page's engine staged, so
    /// the link keeps its referrer, initiator and security. Only a page on the
    /// same engine and profile as its source, whose engine has not created it
    /// yet, can take the link; the engine checks the link still applies when
    /// the page loads.
    private void Stage(StageLink intent, Action<Engine, EngineCommand> issue) {
        var page = Known(intent.PageId);
        var source = Known(intent.SourcePageId);
        if (!ReferenceEquals(page.Engine, source.Engine) || page.ProfileId != source.ProfileId || page.Phase != PagePhase.Opening)
            throw new Rejected(new StagedLinkElsewhere(page.Id, source.Id));
        issue(page.Engine, new StageNavigation(page.Id, intent.StagedLinkId, intent.Url));
    }

    /// No page will load a staged link, so the engine of the page it was
    /// followed in forgets it. A source page that is gone took its links with it.
    private void Discard(DiscardStagedLink intent, Action<Engine, EngineCommand> issue) {
        if (open.GetValueOrDefault(intent.SourcePageId) is { } source)
            issue(source.Engine, new DropStagedLink(intent.StagedLinkId));
    }

    #endregion
}
