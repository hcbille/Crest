using CrestCore.Application;

namespace CrestCore.Contracts;

/// The page's document, or a frame of its own site, asked for `KeySystem`,
/// which the engine does not have. The core moves the page to an engine that
/// plays protected media through the platform, when one is registered.
public sealed record ProtectedMediaUnavailable(Guid PageId, KeySystem KeySystem) : PageEvent(PageId) {
    #region Actions - Pages

    /// Moves the live page to an engine that plays protected media through
    /// the platform, and opens the page's site there from then on. Nothing
    /// moves while the page's Space may not show it, when no other engine
    /// plays it, when the page moved for this once already, so it never
    /// bounces between engines, when its document is not a web page's, or
    /// when its site has an engine chosen for it, as a person who moved it
    /// back chose.
    internal override void Apply(Pages pages, Page page, PageTurn turn) {
        if (page.Phase != PagePhase.Live || pages.Shown(page) is not { } space || page.MovedFor(RehostReason.ProtectedMedia)
            || pages.Engines.PlayingProtectedMedia(page.Engine) is not { } fallback
            || page.DocumentAddress is not { } address || new WebAddress(address).Origin is not { } origin
            || pages.Device.ChosenEngine(space.Id, origin) is not null)
            return;
        pages.Device.Choose(space.Id, origin, fallback.Kind);
        pages.Rehost(page, fallback, address, RehostReason.ProtectedMedia, turn);
    }

    #endregion
}
