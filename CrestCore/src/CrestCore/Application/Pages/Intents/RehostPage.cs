using CrestCore.Application;

namespace CrestCore.Contracts;

/// Moves a page to `Engine`. The core closes the page on its engine, keeping
/// nothing, creates it on `Engine` in the same profile and window, and once
/// that engine has created it, loads the address the page showed. The page
/// keeps its identity, its owner and its window; its history, form state and
/// anything its old engine kept stay behind. A page already on `Engine`
/// stays. Refused when the page is not open, its Space is locked or being
/// deleted, or this device did not register `Engine`.
public sealed record RehostPage(Guid PageId, EngineKind Engine) : PageIntent {
    #region Actions - Pages

    internal override void Apply(Pages pages, PageTurn turn) {
        var page = pages.Known(PageId);
        pages.Hosting(pages.Device.Workspace(page.WorkspaceId), page.SpaceId);
        var engine = pages.Engines.Registered(Engine) ?? throw new Rejected(new UnregisteredEngine(Engine));
        if (!ReferenceEquals(engine, page.Engine)) pages.Rehost(page, engine, page.Live.Address, RehostReason.PersonAsked, turn);
    }

    #endregion
}
