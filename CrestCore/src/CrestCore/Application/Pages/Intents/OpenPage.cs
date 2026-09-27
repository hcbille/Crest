using CrestCore.Application;

namespace CrestCore.Contracts;

/// Opens a page for a tab, or for a transient request when `TabId` is null, in
/// a Space of a workspace attached to this device, hosted by an open window.
/// `Transient` says how a page with no tab presents. The page opens on the
/// engine chosen for the site its tab shows (`ChooseSiteEngine`) when that
/// engine is registered, and otherwise on the default engine; that engine is
/// asked to create it. Refused when the workspace,
/// Space or window is not there, the Space is locked or being deleted, the
/// window already hosts a page for the tab, or no engine is the default.
public sealed record OpenPage(Guid PageId, Guid WorkspaceId, Guid SpaceId, Guid? TabId, Guid WindowId,
    TransientPresentation? Transient = null) : PageIntent {
    #region Actions - Pages

    /// A tab's page restores what the tab's last page kept, when it closed
    /// keeping its state on the same engine at the address the tab shows.
    internal override void Apply(Pages pages, PageTurn turn) {
        if (pages.IsOpen(PageId)) throw new Rejected(new DuplicatePage(PageId));
        var workspace = pages.Device.Workspace(WorkspaceId);
        pages.Device.Opened(WindowId);
        var space = pages.Hosting(workspace, SpaceId);
        pages.RequireUnowned(WorkspaceId, WindowId, TabId, moving: null);
        var tab = space.Tabs.FirstOrDefault(held => held.Id == TabId);
        var engine = pages.Chosen(space, tab) ?? pages.Engines.Default ?? throw new Rejected(new EngineNotRegistered());
        var page = new Page(PageId, engine, space.ProfileId, WorkspaceId, space.Id, TabId, WindowId, Transient);
        pages.Add(page);
        var restore = TabId is { } tabId ? pages.Restorable(WorkspaceId, space, tabId, engine.Kind) : null;
        if (restore is not null) page.Restoring(restore.Url);
        turn.Changes.Publish(new PageOpened(page.State));
        turn.Issue(engine, new CreatePage(page.Id, page.ProfileId, workspace.IsPrivateBrowsing, page.WindowId, restore));
    }

    #endregion
}
