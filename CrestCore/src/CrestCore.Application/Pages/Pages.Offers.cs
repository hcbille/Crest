using CrestCore.Contracts;

namespace CrestCore.Application;

internal sealed partial class Pages {
    #region Actions - Offered pages

    /// The engine opened a page of its own, and the core decides where it
    /// belongs:
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
    public void Report(Engine engine, PageOffered offer, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(offer);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        var source = offer.SourcePageId is { } sourceId && open.GetValueOrDefault(sourceId) is { } opener
            && ReferenceEquals(opener.Engine, engine) && opener.ProfileId == offer.ProfileId
                ? opener
                : null;
        if (source is { TabId: null }) {
            issue(engine, new RejectOfferedPage(offer.OfferId));
            LoadInSource(source, offer.Url, changes, issue);
            return;
        }
        if (!Adopted(engine, offer, source, changes, issue)) issue(engine, new RejectOfferedPage(offer.OfferId));
    }

    /// Opens the offered page's tab and gives the page to it, and answers
    /// whether a Space took it.
    private bool Adopted(Engine engine, PageOffered offer, Page? source, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        Guid workspaceId, windowId, spaceId;
        Guid? afterTabId;
        if (source is { TabId: { } sourceTab }) {
            (workspaceId, windowId, spaceId, afterTabId) = (source.WorkspaceId, source.WindowId, source.SpaceId, sourceTab);
        } else if (offer.WindowId is { } holder && device.Showing(holder, offer.SpaceId) is { } shown) {
            windowId = holder;
            (workspaceId, spaceId, afterTabId) = shown;
        } else {
            return false;
        }
        if (device.Attached(workspaceId) is not { } workspace || Hostable(workspace, spaceId) is not { } space
            || space.ProfileId != offer.ProfileId)
            return false;
        var tabId = ids.Next();
        try {
            workspace.Handle(new OpenTab(workspaceId, windowId, space.Id, tabId,
                new TabContent(offer.Url, View: null, Title: null), TabPlacement.Current, afterTabId, offer.Foreground),
                clock.Now, ids, this);
        } catch (Rejected) {
            // The Space's tabs are full, or the address is one no tab shows.
            return false;
        }
        var page = new Page(ids.Next(), engine, space.ProfileId, workspaceId, space.Id, tabId, windowId, transient: null);
        open[page.Id] = page;
        changes.Publish(new PageOpened(page.State));
        changes.Publish(new OfferedPageAdopted(page.Id, workspaceId, windowId, space.Id, tabId, offer.Foreground));
        issue(engine, new AdoptOfferedPage(page.Id, offer.OfferId, page.ProfileId, workspace.IsPrivateBrowsing, windowId));
        return true;
    }

    /// A Quick Window's or Peek's page loads the web address a page it opened
    /// was heading to. One whose engine holds no page, whose Space may not
    /// show it now, or an address that is not the web loads nothing.
    private void LoadInSource(Page source, string url, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        if (!source.Phase.HoldsEnginePage || new WebAddress(url).Origin is null
            || device.Attached(source.WorkspaceId) is not { } workspace || Hostable(workspace, source.SpaceId) is null)
            return;
        Update(source, changes, () => source.Load(url));
        issue(source.Engine, new LoadPage(source.Id, url));
    }

    /// The Space a page may live in, as `Hosting` decides, or null where a
    /// rule refuses it.
    private static SpaceState? Hostable(NativeSessionAuthority workspace, Guid spaceId) =>
        workspace.Current.Spaces.FirstOrDefault(space => space.Id == spaceId) is { } space && !workspace.IsDeleting(spaceId)
            && !workspace.IsLocked(space)
            ? space
            : null;

    #endregion
}
