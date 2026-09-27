using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

#region Types

/// What one page intent needs: where it publishes what it changed, and where
/// it hands the engine commands it causes, which reach their engines once the
/// core lets go of its lock.
internal sealed record PageTurn(ChangeFeed Changes, Action<Engine, EngineCommand> Issue);

/// What one report about a hosted page needs: the page, which the reporting
/// engine hosts, and where the report publishes and issues, as a page intent
/// does.
internal sealed record PageEventTurn(Page Page, ChangeFeed Changes, Action<Engine, EngineCommand> Issue);

#endregion

/// The pages this device hosts: which tab or transient request owns each, the
/// window that hosts it, the engine that hosts it and the live state its
/// engine reports. Never saved or synced. The platform decides when a page
/// opens or goes; the core decides whether it may, and on which engine, and
/// asks the engine to create, load and close it. A tab's page opens on the
/// engine chosen for the site the tab shows, when that engine is registered,
/// and on the default engine otherwise. A page moves to another engine when
/// the person asks, when it heads to a site chosen for another engine, or
/// when it asks for protected media its engine cannot play and another plays
/// it through the platform.
///
/// A window hosts one page for a tab. The Mac's windows over one workspace
/// share one runtime store, so a second window shows the page the first opened
/// and never opens its own; each iPad scene keeps pages of its own, so two
/// scenes showing one tab each host a page for it.
///
/// A page's report is stamped with the core's `clock`, and a visit it records
/// takes its identity from `ids`.
internal sealed partial class Pages(Device device, Engines engines, IClock clock, IIdSource ids)
    : IPageIntentHandler<PageTurn>, IPageEventHandler<PageEventTurn> {
    #region Variables

    private readonly Dictionary<Guid, Page> open = [];

    /// What each Quick Window or Peek page its owner unloaded showed last, by
    /// page, so its window can still keep or archive it. A page is remembered
    /// until the session keeps or archives it, its owner releases it for good
    /// or its workspace closes, so the list holds no more than the transient
    /// windows still open.
    private readonly Dictionary<Guid, TransientPage> unloaded = [];
    /// What each tab's last page kept when it closed keeping its state, which
    /// the tab's next page restores. Memory only, never saved or synced; a tab
    /// that closes, is archived or loses its Space loses it.
    private readonly Dictionary<(Guid WorkspaceId, Guid TabId), (Guid SpaceId, EngineKind Engine, PageRestoreState State)> restoreStates = [];
    /// The pages asked to close keeping their state, until their engine says
    /// they are gone.
    private readonly Dictionary<Guid, (Engine Engine, Guid WorkspaceId, Guid SpaceId, Guid TabId)> keeping = [];
    /// The most restore states the core holds; past it, the oldest goes.
    private const int MaximumRestoreStates = 64;
    private readonly List<(Guid WorkspaceId, Guid TabId)> restoreOrder = [];

    /// The engines a page is open on.
    public IReadOnlySet<EngineKind> HostingEngines => open.Values.Select(page => page.Engine.Kind).ToHashSet();

    /// Whether the engine new pages open on shows internal pages, such as an
    /// engine's settings.
    public bool OpensInternalPages => engines.Default?.Supports(EngineCapability.InternalPages) == true;

    #endregion

    #region Actions - Intents

    /// Runs one page intent, publishing what it changed to the turn's changes
    /// and handing the engine commands it causes to its `Issue`.
    public void Handle(PageIntent intent, PageTurn turn) => intent.Dispatch(this, turn);

    public void Handle(OpenPage intent, PageTurn turn) {
        if (open.ContainsKey(intent.PageId)) throw new Rejected(new DuplicatePage(intent.PageId));
        var workspace = device.Workspace(intent.WorkspaceId);
        device.Opened(intent.WindowId);
        var space = Hosting(workspace, intent.SpaceId);
        RequireUnowned(intent.WorkspaceId, intent.WindowId, intent.TabId, moving: null);
        var tab = space.Tabs.FirstOrDefault(held => held.Id == intent.TabId);
        var engine = Chosen(space, tab) ?? engines.Default ?? throw new Rejected(new EngineNotRegistered());
        var page = new Page(intent.PageId, engine, space.ProfileId, intent.WorkspaceId, space.Id, intent.TabId, intent.WindowId,
            intent.Transient);
        open[page.Id] = page;
        var restore = intent.TabId is { } tabId ? Restorable(intent.WorkspaceId, space, tabId, engine.Kind) : null;
        if (restore is not null) page.Restoring(restore.Url);
        turn.Changes.Publish(new PageOpened(page.State));
        turn.Issue(engine, new CreatePage(page.Id, page.ProfileId, workspace.IsPrivateBrowsing, page.WindowId, restore));
    }

    public void Handle(MovePage intent, PageTurn turn) {
        var page = Known(intent.PageId);
        var workspace = device.Workspace(intent.WorkspaceId);
        device.Opened(intent.WindowId);
        var space = Hosting(workspace, intent.SpaceId);
        if (space.ProfileId != page.ProfileId) throw new Rejected(new PageProfileMismatch(page.Id, space.Id));
        RequireUnowned(intent.WorkspaceId, intent.WindowId, intent.TabId, moving: page);
        var before = page.State;
        page.Move(intent.WorkspaceId, space.Id, intent.TabId, intent.WindowId);
        if (page.State != before) turn.Changes.Publish(new PageChanged(page.State));
    }

    /// The page is gone at once, so its tab may open another straight away;
    /// the engine closes what it still holds afterwards. A Quick Window's or
    /// Peek's page its owner unloaded, keeping what it needs to bring it back,
    /// leaves what it showed last; releasing it again for good forgets that.
    public void Handle(ReleasePage intent, PageTurn turn) {
        if (!open.Remove(intent.PageId, out var page)) {
            if (!unloaded.ContainsKey(intent.PageId)) throw new Rejected(new UnknownPage(intent.PageId));
            if (!intent.KeepsState) unloaded.Remove(intent.PageId);
            return;
        }
        if (page.TabId is null && intent.KeepsState) unloaded[page.Id] = Transient(page) with { MovesBetweenWindows = false };
        turn.Changes.Publish(new PageRemoved(page.Id));
        if (page.Phase.HoldsEnginePage) Close(page, intent.KeepsState, turn.Issue);
    }

    /// Resolves what the person asked for by the address rules of the page's
    /// Space and engine, shows the page heading there at once, and asks its
    /// engine to load it. A load to a site chosen for another registered
    /// engine moves the page there, which loads it instead.
    public void Handle(Navigate intent, PageTurn turn) {
        var page = Known(intent.PageId);
        if (!page.Phase.HoldsEnginePage) throw new Rejected(new PageNotLoadable(page.Id));
        var space = Hosting(device.Workspace(page.WorkspaceId), page.SpaceId);
        var url = AddressResolution.Loading(intent.Input, space.Settings.BrowsingPreferences,
            page.Engine.Supports(EngineCapability.InternalPages));
        if (Chosen(space, url) is { } chosen && !ReferenceEquals(chosen, page.Engine)) {
            Rehost(page, chosen, url, RehostReason.SiteChoice, turn.Changes, turn.Issue);
            return;
        }
        Update(page, turn.Changes, () => page.Load(url));
        turn.Issue(page.Engine, new LoadPage(page.Id, url));
    }

    /// Moves the page to the engine the person asked for, which loads the
    /// address it shows.
    public void Handle(RehostPage intent, PageTurn turn) {
        var page = Known(intent.PageId);
        Hosting(device.Workspace(page.WorkspaceId), page.SpaceId);
        var engine = engines.Registered(intent.Engine) ?? throw new Rejected(new UnregisteredEngine(intent.Engine));
        if (!ReferenceEquals(engine, page.Engine))
            Rehost(page, engine, page.Live.Address, RehostReason.PersonAsked, turn.Changes, turn.Issue);
    }

    /// Closes the page on its engine, keeping nothing, and creates it on
    /// `engine`, which loads `address` once it has created it, then publishes
    /// the move and why it happened.
    private void Rehost(Page page, Engine engine, string? address, RehostReason reason, ChangeFeed changes,
        Action<Engine, EngineCommand> issue) {
        var from = page.Engine;
        if (page.Phase.HoldsEnginePage) issue(from, new ClosePage(page.Id, KeepsState: false));
        Update(page, changes, () => page.Rehost(engine, address, reason));
        issue(engine, new CreatePage(page.Id, page.ProfileId, device.Workspace(page.WorkspaceId).IsPrivateBrowsing, page.WindowId,
            RestoreState: null));
        changes.Publish(new PageRehosted(page.Id, page.SpaceId, address is null ? null : new WebAddress(address).Origin, from.Kind,
            engine.Kind, reason));
    }

    /// Moves a page that asked for protected media its engine cannot play to
    /// an engine that plays it through the platform, and opens the page's
    /// site there from then on. Nothing moves when no other engine plays it,
    /// when the page moved for this once already, so it never bounces between
    /// engines, when its document is not a web page's, or when its site has an
    /// engine chosen for it, as a person who moved it back chose.
    private void PlayProtectedMedia(Page page, SpaceState space, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        if (page.MovedFor(RehostReason.ProtectedMedia) || engines.PlayingProtectedMedia(page.Engine) is not { } fallback
            || page.DocumentAddress is not { } address || new WebAddress(address).Origin is not { } origin
            || device.ChosenEngine(space.Id, origin) is not null)
            return;
        device.Choose(space.Id, origin, fallback.Kind);
        Rehost(page, fallback, address, RehostReason.ProtectedMedia, changes, issue);
    }

    /// The registered engine chosen for the site `tab` shows, or null when
    /// none is, or for a page without a tab, which opens before it has an
    /// address.
    private Engine? Chosen(SpaceState space, TabState? tab) => tab?.Url is { } url ? Chosen(space, url) : null;

    /// The registered engine chosen in `space` for the site `url` belongs to,
    /// or null when none is.
    private Engine? Chosen(SpaceState space, string url) =>
        new WebAddress(url).Origin is { } origin && device.ChosenEngine(space.Id, origin) is { } kind ? engines.Registered(kind) : null;

    public void Handle(LeavePageFailure intent, PageTurn turn) {
        var page = Known(intent.PageId);
        Update(page, turn.Changes, page.LeaveFailure);
    }

    #endregion

    #region Actions - Workspaces

    /// A workspace closed: each of its pages is gone at once, and its engine
    /// closes what it still holds afterwards, keeping nothing. What its Quick
    /// Window or Peek pages showed when their owners unloaded them is
    /// forgotten too.
    public void Drop(Guid workspaceId, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        foreach (var page in open.Values.Where(page => page.WorkspaceId == workspaceId).ToArray()) {
            open.Remove(page.Id);
            changes.Publish(new PageRemoved(page.Id));
            if (page.Phase.HoldsEnginePage) issue(page.Engine, new ClosePage(page.Id, KeepsState: false));
        }
        foreach (var remembered in unloaded.Values.Where(remembered => remembered.WorkspaceId == workspaceId).ToArray())
            unloaded.Remove(remembered.Id);
        foreach (var key in restoreStates.Keys.Where(key => key.WorkspaceId == workspaceId).ToArray()) Forget(key);
    }

    #endregion

    #region Actions - Queries

    /// Whether returning the tab to its saved address changes anything: it is
    /// away from that page, or its page in the window is heading to another.
    /// A tab that belongs nowhere, is gone or lives in a locked Space does not.
    public SavedAddressReturn Answer(CanReturnToSavedAddress question) {
        ArgumentNullException.ThrowIfNull(question);
        var workspace = device.Workspace(question.WorkspaceId);
        if (workspace.Current.Spaces.FirstOrDefault(space => space.Id == question.SpaceId) is not { } space
            || workspace.IsLocked(space)
            || space.Tabs.FirstOrDefault(tab => tab.Id == question.TabId) is not { SavedAddress: { } saved } tab)
            return new(ChangesPage: false);
        if (tab.IsAwayFromSavedAddress) return new(ChangesPage: true);
        var heading = Showing(question.WorkspaceId, question.WindowId, tab.Id)?.PendingUrl;
        return new(ChangesPage: heading is { } pending && !new WebAddress(pending).IsSamePage(new WebAddress(saved)));
    }

    /// The live state of the page that shows `tabId` of a workspace in
    /// `windowId`, or in another window of the workspace when that window
    /// hosts none, or null when no page shows the tab.
    public PageLiveState? Showing(Guid workspaceId, Guid windowId, Guid tabId) {
        PageLiveState? elsewhere = null;
        foreach (var page in open.Values) {
            if (page.WorkspaceId != workspaceId || page.TabId != tabId || !page.Phase.HoldsEnginePage) continue;
            if (page.WindowId == windowId) return page.Live;
            elsewhere ??= page.Live;
        }
        return elsewhere;
    }

    #endregion

    #region Actions - Reports

    /// Applies what an engine saw happen to one of its pages. A report about a
    /// page the core no longer knows, one another engine hosts, or one that
    /// would move a page backwards changes nothing. What the engine shows, a
    /// failure and a commit that ends it change the page's live state, which
    /// is published only when it differs. A finished navigation is recorded
    /// once per document in the Space the page lives in, and an icon reported
    /// for a recorded document goes to the page's tab; either waits while a
    /// transaction holds the workspace's session.
    ///
    /// A page whose renderer stopped comes back by the core's crash recovery,
    /// which hands the engine command it causes to `issue`.
    public void Report(Engine engine, PageEvent report, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        // A page closed keeping its state hands back what brings it back,
        // though the core let the page go when it asked the engine to close it.
        if (report is PageClosed closedKeeping && keeping.Remove(closedKeeping.PageId, out var kept) && ReferenceEquals(kept.Engine, engine)
            && closedKeeping.RestoreState is { } restoreState)
            Keep((kept.WorkspaceId, kept.TabId), kept.SpaceId, engine.Kind, restoreState);
        if (!open.TryGetValue(report.PageId, out var page) || !ReferenceEquals(page.Engine, engine)) return;
        report.Dispatch(this, new PageEventTurn(page, changes, issue));
    }

    public void Handle(PageCreated report, PageEventTurn turn) {
        Enter(turn.Page, PagePhase.Live, turn.Changes);
        if (turn.Page.TakeRehostedAddress() is { } address) turn.Issue(turn.Page.Engine, new LoadPage(turn.Page.Id, address));
    }

    public void Handle(PageCreationFailed report, PageEventTurn turn) => Enter(turn.Page, PagePhase.Failed, turn.Changes);

    public void Handle(PageClosed report, PageEventTurn turn) => Enter(turn.Page, PagePhase.Closed, turn.Changes);

    /// A navigation to another document of a site chosen for another
    /// registered engine moves the page there, which loads it instead.
    /// Otherwise nothing is recorded until the navigation finishes.
    public void Handle(NavigationStarted report, PageEventTurn turn) {
        var page = turn.Page;
        if (!report.SameDocument && Shown(page) is { } space && Chosen(space, report.Url) is { } chosen
            && !ReferenceEquals(chosen, page.Engine))
            Rehost(page, chosen, report.Url, RehostReason.SiteChoice, turn.Changes, turn.Issue);
    }

    public void Handle(ProtectedMediaUnavailable report, PageEventTurn turn) {
        if (turn.Page.Phase == PagePhase.Live && Shown(turn.Page) is { } space) PlayProtectedMedia(turn.Page, space, turn.Changes, turn.Issue);
    }

    public void Handle(NavigationCommitted report, PageEventTurn turn) =>
        Update(turn.Page, turn.Changes, () => turn.Page.Commit(report.Url, report.SameDocument));

    public void Handle(NavigationFinished report, PageEventTurn turn) {
        var page = turn.Page;
        if (page.Finish(report.Url))
            Edit(page, new NavigationRecord(page.Id, page.SpaceId, clock.Now, page.TabId, report.Url, report.Title, page.Icon, ids.Next()),
                turn.Changes);
    }

    public void Handle(NavigationFailed report, PageEventTurn turn) => Update(turn.Page, turn.Changes, () => turn.Page.Fail(report.Failure));

    public void Handle(PageIconChanged report, PageEventTurn turn) {
        var page = turn.Page;
        if (page.ShowIcon(new(report.Url, report.Accent)) && page.TabId is { } tabId)
            Edit(page, new IconAdoption(page.Id, page.SpaceId, clock.Now, tabId, page.Icon!), turn.Changes);
    }

    public void Handle(PageStateChanged report, PageEventTurn turn) => Update(turn.Page, turn.Changes, () => turn.Page.Show(report.Snapshot));

    public void Handle(PageCrashed report, PageEventTurn turn) {
        var page = turn.Page;
        if (page.Phase != PagePhase.Live) return;
        var recovers = false;
        Update(page, turn.Changes, () => recovers = page.Crash(IsShown(page), report.Domain, report.Code));
        if (recovers) turn.Issue(page.Engine, new RecoverPage(page.Id));
    }

    /// A stale link is never retried as a bare address, so the page stops
    /// heading there and shows what it had.
    public void Handle(StagedLinkUnavailable report, PageEventTurn turn) => Update(turn.Page, turn.Changes, turn.Page.CancelLoad);

    /// Brings back each page whose renderer stopped while nobody saw it and
    /// that a window now shows, or shows its failure once the recovery budget
    /// is spent.
    public void RecoverShown(ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        foreach (var page in open.Values.Where(page => page.RecoversWhenShown && page.Phase == PagePhase.Live && IsShown(page))) {
            var recovers = false;
            Update(page, changes, () => recovers = page.Recover());
            if (recovers) issue(page.Engine, new RecoverPage(page.Id));
        }
    }

    /// Whether a window shows the page: a Quick Window's or Peek's page always,
    /// a tab's page when a window over its workspace shows the tab or a split
    /// it belongs to.
    private bool IsShown(Page page) => page.TabId is not { } tabId || device.Shows(page.WorkspaceId, page.SpaceId, tabId);

    /// Applies `update` to the page, and publishes the page when that changed
    /// what readers see of it.
    private static void Update(Page page, ChangeFeed changes, Action update) {
        var before = page.State;
        update();
        if (page.State != before) changes.Publish(new PageChanged(page.State));
    }

    private static void Enter(Page page, PagePhase next, ChangeFeed changes) {
        if (page.Enter(next)) changes.Publish(new PageChanged(page.State));
    }

    /// Applies a page's edit to the session of the workspace it lives in; a
    /// workspace that is gone takes nothing.
    private void Edit(Page page, PageEdit edit, ChangeFeed changes) {
        if (device.Attached(page.WorkspaceId) is not { } workspace) return;
        foreach (var change in workspace.Apply(edit)) changes.Publish(change);
    }

    #endregion

    #region Actions - Residency

    /// Unloads the pages memory pressure may take back: off screen, live on
    /// an engine that can bring them back, showing a document, owned by a tab
    /// that does not keep its page loaded, and running no media. A page that
    /// has shown no document yet stays: nothing of it could come back, and a
    /// popup waiting for its first document would lose the page that opened
    /// it. The pages off screen longest go first, as many as the device's
    /// platform gives back at the intent's level.
    public void Handle(ReportMemoryPressure intent, PageTurn turn) {
        Stamp(clock.Now);
        const PageMediaActivity keepsLoaded = PageMediaActivity.Playing | PageMediaActivity.Capturing | PageMediaActivity.PictureInPicture;
        var candidates = open.Values
            .Where(page => page.TabId is not null && page.Phase == PagePhase.Live && page.HiddenSince is not null
                && page.Live.Url is not null && page.Engine.Supports(EngineCapability.PageResidency)
                && (page.Live.Media & keepsLoaded) == 0
                && Tab(page) is { KeepsPageLoaded: false })
            .OrderBy(page => page.HiddenSince).ThenBy(page => page.Id)
            .ToArray();
        foreach (var page in candidates.Take(device.Platform.ReleaseLimit(intent.Level, candidates.Length))) {
            open.Remove(page.Id);
            turn.Changes.Publish(new PageRemoved(page.Id));
            turn.Changes.Publish(new PageUnloaded(page.Id, page.WorkspaceId, page.TabId!.Value));
            Close(page, keepsState: true, turn.Issue);
        }
    }

    /// Stamps each tab's page with whether a window shows it now.
    public void Stamp(DateTimeOffset now) {
        var shown = new Dictionary<Guid, IReadOnlySet<Guid>>();
        foreach (var page in open.Values) {
            if (page.TabId is not { } tabId) continue;
            if (!shown.TryGetValue(page.WorkspaceId, out var tabs)) shown[page.WorkspaceId] = tabs = device.OnScreenTabs(page.WorkspaceId);
            page.Seen(tabs.Contains(tabId), now);
        }
    }

    /// Forgets what a tab kept once the tab is gone from its Space, closed or
    /// archived, or its Space is gone or being deleted.
    public void PruneRestoreStates() {
        foreach (var (key, kept) in restoreStates.ToArray())
            if (Held(key.WorkspaceId, kept.SpaceId, key.TabId) is null) Forget(key);
    }

    /// Asks the engine to close the page. A tab's page closed keeping its
    /// state hands back what brings it back, which the tab keeps.
    private void Close(Page page, bool keepsState, Action<Engine, EngineCommand> issue) {
        if (keepsState && page.TabId is { } tabId) keeping[page.Id] = (page.Engine, page.WorkspaceId, page.SpaceId, tabId);
        issue(page.Engine, new ClosePage(page.Id, keepsState));
    }

    /// What the tab kept for its next page, taken once, when the tab still
    /// shows the address it kept and the page opens on the engine that kept
    /// it. What it kept for another address or engine is dropped.
    private PageRestoreState? Restorable(Guid workspaceId, SpaceState space, Guid tabId, EngineKind engine) {
        var key = (workspaceId, tabId);
        if (!restoreStates.TryGetValue(key, out var kept)) return null;
        Forget(key);
        var tab = space.Tabs.FirstOrDefault(tab => tab.Id == tabId);
        return kept.SpaceId == space.Id && kept.Engine == engine && tab?.Url is { } url
            && new WebAddress(url).IsSamePage(new WebAddress(kept.State.Url)) ? kept.State : null;
    }

    private void Keep((Guid WorkspaceId, Guid TabId) key, Guid spaceId, EngineKind engine, PageRestoreState state) {
        Forget(key);
        restoreStates[key] = (spaceId, engine, state);
        restoreOrder.Add(key);
        while (restoreOrder.Count > MaximumRestoreStates) Forget(restoreOrder[0]);
    }

    private void Forget((Guid WorkspaceId, Guid TabId) key) {
        restoreStates.Remove(key);
        restoreOrder.Remove(key);
    }

    /// The tab a page belongs to, as its Space holds it now.
    private TabState? Tab(Page page) => page.TabId is { } tabId ? Held(page.WorkspaceId, page.SpaceId, tabId) : null;

    /// The Space a page lives in, while its workspace is attached, the Space
    /// is not being deleted and this process may show it; null otherwise.
    private SpaceState? Shown(Page page) =>
        device.Attached(page.WorkspaceId) is { } workspace && !workspace.IsDeleting(page.SpaceId)
            && workspace.Current.Spaces.FirstOrDefault(space => space.Id == page.SpaceId) is { } space && !workspace.IsLocked(space)
            ? space : null;

    /// A tab its Space still holds, in a Space that is not being deleted.
    private TabState? Held(Guid workspaceId, Guid spaceId, Guid tabId) =>
        device.Attached(workspaceId) is { } workspace && !workspace.IsDeleting(spaceId)
            && workspace.Current.Spaces.FirstOrDefault(space => space.Id == spaceId) is { } space
            ? space.Tabs.FirstOrDefault(tab => tab.Id == tabId) : null;

    #endregion

    #region Actions - Rules

    /// The page `pageId` names while the core hosts it, or null.
    public Page? Hosted(Guid pageId) => open.GetValueOrDefault(pageId);

    /// Every page the core hosts.
    public IReadOnlyCollection<Page> All => open.Values;

    private Page Known(Guid pageId) => open.TryGetValue(pageId, out var page) ? page : throw new Rejected(new UnknownPage(pageId));

    /// The Quick Window or Peek page `pageId` names, as it is or as it was
    /// when its owner unloaded it, or null when this device hosts no such page
    /// and remembers none. An unloaded page cannot move to a tab's window, and
    /// one of a workspace that closed is not remembered.
    public TransientPage? Transient(Guid pageId) => open.TryGetValue(pageId, out var page)
        ? page.TabId is null ? Transient(page) : null
        : unloaded.GetValueOrDefault(pageId);

    /// Forgets an unloaded Quick Window or Peek page the session kept or
    /// archived.
    public void Completed(Guid pageId) => unloaded.Remove(pageId);

    private static TransientPage Transient(Page page) => new(page.Id, page.WorkspaceId, page.SpaceId, page.ProfileId,
        page.Engine.Supports(EngineCapability.WorkspaceTransfer), page.Live.Address, page.Live.Title);

    /// The Space a page may live in: one the workspace holds, that is not
    /// being deleted, here or in the workspace a borrowed one borrows from, and
    /// that this process may show.
    private static SpaceState Hosting(NativeSessionAuthority workspace, Guid spaceId) {
        var space = workspace.Current.Spaces.FirstOrDefault(space => space.Id == spaceId) ?? throw new Rejected(new UnknownSpace(spaceId));
        if (workspace.IsDeleting(spaceId)) throw new Rejected(new SpaceBeingDeleted(spaceId));
        if (workspace.IsLocked(space)) throw new Rejected(new SpaceLocked(spaceId));
        return space;
    }

    /// A window hosts one page for a tab at a time. Whether the workspace holds
    /// the tab is not checked yet: selection can present a tab before the
    /// core's session has it, and an `UnknownTab` rejection arrives with the
    /// session intents.
    private void RequireUnowned(Guid workspaceId, Guid windowId, Guid? tabId, Page? moving) {
        if (tabId is not { } tab) return;
        if (open.Values.FirstOrDefault(page => page != moving && page.WorkspaceId == workspaceId && page.WindowId == windowId
            && page.TabId == tab) is { } owner)
            throw new Rejected(new TabAlreadyHasPage(tab, owner.Id));
    }

    #endregion
}
