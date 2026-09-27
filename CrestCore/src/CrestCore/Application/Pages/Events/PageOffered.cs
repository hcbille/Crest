using CrestCore.Application;

namespace CrestCore.Contracts;

/// The engine opened a page of its own in the profile `ProfileId` names: a
/// script's `window.open`, a link to a new window or tab, or an extension's
/// tab. The page stays on the engine that opened it, which is its opener's.
/// `SourcePageId` names the page that opened it, when one did. Otherwise
/// `WindowId` names the Crest window whose engine window holds it, and
/// `SpaceId` the Space a window the engine created for itself was reserved
/// for. `Url` is where it is heading, and `Foreground` whether the engine
/// brought it to the front. The core adopts it with `AdoptOfferedPage` or
/// refuses it with `RejectOfferedPage`.
public sealed record PageOffered(Guid OfferId, Guid ProfileId, Guid? SourcePageId, Guid? WindowId, Guid? SpaceId, string Url,
    bool Foreground) : EngineEvent {
    #region Actions - Pages

    /// The core decides where the page `engine` offered belongs:
    ///
    /// - A Quick Window's or Peek's page keeps what it opens. The engine
    ///   closes the offered page, and the page that opened it loads its web
    ///   address, as a popup there does on every engine.
    /// - A tab's page opens a tab after its own, in its Space and window.
    /// - Any other page joins the window that holds it: the Space its engine
    ///   window was reserved for, or else the Space the window shows, after
    ///   the tab the window shows there.
    ///
    /// The new tab owns the offered page, and the window shows it when the
    /// engine brought the page to the front. A Space that is locked, being
    /// deleted or of another profile, a window that is not open, or a tab the
    /// Space cannot take refuses the page, and the engine closes it.
    internal void Apply(Pages pages, Engine engine, PageTurn turn) {
        var source = SourcePageId is { } sourceId && pages.Hosted(sourceId) is { } opener
            && ReferenceEquals(opener.Engine, engine) && opener.ProfileId == ProfileId
                ? opener
                : null;
        if (source is { TabId: null }) {
            turn.Issue(engine, new RejectOfferedPage(OfferId));
            LoadInSource(pages, source, turn);
            return;
        }
        if (!Adopted(pages, engine, source, turn)) turn.Issue(engine, new RejectOfferedPage(OfferId));
    }

    /// Opens the offered page's tab and gives the page to it, and answers
    /// whether a Space took it.
    private bool Adopted(Pages pages, Engine engine, Page? source, PageTurn turn) {
        Guid workspaceId, windowId, spaceId;
        Guid? afterTabId;
        if (source is { TabId: { } sourceTab }) {
            (workspaceId, windowId, spaceId, afterTabId) = (source.WorkspaceId, source.WindowId, source.SpaceId, sourceTab);
        } else if (WindowId is { } holder && pages.Device.Showing(holder, SpaceId) is { } shown) {
            windowId = holder;
            (workspaceId, spaceId, afterTabId) = shown;
        } else {
            return false;
        }
        if (pages.Device.Attached(workspaceId) is not { } workspace || Hostable(workspace, spaceId) is not { } space
            || space.ProfileId != ProfileId)
            return false;
        var tabId = pages.Ids.Next();
        try {
            workspace.Handle(new OpenTab(workspaceId, windowId, space.Id, tabId,
                new TabContent(Url, View: null, Title: null), TabPlacement.Current, afterTabId, Foreground),
                pages.Clock.Now, pages.Ids, pages);
        } catch (Rejected) {
            // The Space's tabs are full, or the address is one no tab shows.
            return false;
        }
        var page = new Page(pages.Ids.Next(), engine, space.ProfileId, workspaceId, space.Id, tabId, windowId, transient: null,
            openedByPage: source is not null);
        pages.Add(page);
        turn.Changes.Publish(new PageOpened(page.State));
        turn.Changes.Publish(new OfferedPageAdopted(page.Id, workspaceId, windowId, space.Id, tabId, Foreground));
        turn.Issue(engine, new AdoptOfferedPage(page.Id, OfferId, page.ProfileId, workspace.IsPrivateBrowsing, windowId));
        return true;
    }

    /// A Quick Window's or Peek's page loads the web address a page it opened
    /// was heading to. One whose engine holds no page, whose Space may not
    /// show it now, or an address that is not the web loads nothing.
    private void LoadInSource(Pages pages, Page source, PageTurn turn) {
        if (!source.Phase.HoldsEnginePage || new WebAddress(Url).Origin is null
            || pages.Device.Attached(source.WorkspaceId) is not { } workspace || Hostable(workspace, source.SpaceId) is null)
            return;
        pages.Update(source, turn.Changes, () => source.Load(Url));
        turn.Issue(source.Engine, new LoadPage(source.Id, Url));
    }

    /// The Space a page may live in, as `Pages.Hosting` decides, or null where
    /// a rule refuses it.
    private static SpaceState? Hostable(NativeSessionAuthority workspace, Guid spaceId) =>
        workspace.Current.Spaces.FirstOrDefault(space => space.Id == spaceId) is { } space && !workspace.IsDeleting(spaceId)
            && !workspace.IsLocked(space)
            ? space
            : null;

    #endregion

    #region Actions - Routing

    internal override void Route(CrestApp app, Engine engine, ChangeFeed changes) {
        Apply(app.Pages, engine, new PageTurn(changes, app.Issue));
        app.AfterPageReport(changes);
    }

    #endregion
}
