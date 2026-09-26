using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The pages this device hosts: which tab or transient request owns each, the
/// window that hosts it, the engine that hosts it and the live state its
/// engine reports. Never saved or synced. The platform decides when a page
/// opens or goes; the core decides whether it may, and on which engine, and
/// asks the engine to create, load and close it. A tab's page opens on the
/// engine chosen for the site the tab shows, when that engine is registered,
/// and on the default engine otherwise. A page moves to another engine when
/// the person asks, or when it heads to a site chosen for another engine.
///
/// A window hosts one page for a tab. The Mac's windows over one workspace
/// share one runtime store, so a second window shows the page the first opened
/// and never opens its own; each iPad scene keeps pages of its own, so two
/// scenes showing one tab each host a page for it.
///
/// A page's report is stamped with the core's `clock`, and a visit it records
/// takes its identity from `ids`.
internal sealed class Pages(Device device, Engines engines, IClock clock, IIdSource ids) {
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

    /// Runs one page intent, publishing what it changed to `changes` and
    /// handing the engine commands it causes to `issue`, which delivers them
    /// once the core lets go of its lock.
    public void Handle(PageIntent intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        switch (intent) {
            case OpenPage opening: Open(opening, changes, issue); break;
            case MovePage moving: Move(moving, changes); break;
            case RehostPage rehosting: Rehost(rehosting, changes, issue); break;
            case ReleasePage releasing: Release(releasing, changes, issue); break;
            case Navigate navigation: Load(navigation, changes, issue); break;
            case LeavePageFailure leaving: LeaveFailure(leaving, changes); break;
            case ReportMemoryPressure pressure: Relieve(pressure.Level, changes, issue); break;
            default: throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "Pages do not handle this intent.");
        }
    }

    private void Open(OpenPage intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
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
        changes.Publish(new PageOpened(page.State));
        issue(engine, new CreatePage(page.Id, page.ProfileId, workspace.IsPrivateBrowsing, page.WindowId, restore));
    }

    private void Move(MovePage intent, ChangeFeed changes) {
        var page = Known(intent.PageId);
        var workspace = device.Workspace(intent.WorkspaceId);
        device.Opened(intent.WindowId);
        var space = Hosting(workspace, intent.SpaceId);
        if (space.ProfileId != page.ProfileId) throw new Rejected(new PageProfileMismatch(page.Id, space.Id));
        RequireUnowned(intent.WorkspaceId, intent.WindowId, intent.TabId, moving: page);
        var before = page.State;
        page.Move(intent.WorkspaceId, space.Id, intent.TabId, intent.WindowId);
        if (page.State != before) changes.Publish(new PageChanged(page.State));
    }

    /// The page is gone at once, so its tab may open another straight away;
    /// the engine closes what it still holds afterwards. A Quick Window's or
    /// Peek's page its owner unloaded, keeping what it needs to bring it back,
    /// leaves what it showed last; releasing it again for good forgets that.
    private void Release(ReleasePage intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        if (!open.Remove(intent.PageId, out var page)) {
            if (!unloaded.ContainsKey(intent.PageId)) throw new Rejected(new UnknownPage(intent.PageId));
            if (!intent.KeepsState) unloaded.Remove(intent.PageId);
            return;
        }
        if (page.TabId is null && intent.KeepsState) unloaded[page.Id] = Transient(page) with { MovesBetweenWindows = false };
        changes.Publish(new PageRemoved(page.Id));
        if (page.Phase.HoldsEnginePage) Close(page, intent.KeepsState, issue);
    }

    /// Resolves what the person asked for by the address rules of the page's
    /// Space and engine, shows the page heading there at once, and asks its
    /// engine to load it. A load to a site chosen for another registered
    /// engine moves the page there, which loads it instead.
    private void Load(Navigate intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        var page = Known(intent.PageId);
        if (!page.Phase.HoldsEnginePage) throw new Rejected(new PageNotLoadable(page.Id));
        var space = Hosting(device.Workspace(page.WorkspaceId), page.SpaceId);
        var url = AddressResolution.Loading(intent.Input, space.Settings.BrowsingPreferences,
            page.Engine.Supports(EngineCapability.InternalPages));
        if (Chosen(space, url) is { } chosen && !ReferenceEquals(chosen, page.Engine)) {
            Rehost(page, chosen, url, changes, issue);
            return;
        }
        Update(page, changes, () => page.Load(url));
        issue(page.Engine, new LoadPage(page.Id, url));
    }

    /// Moves the page to the engine the person asked for, which loads the
    /// address it shows.
    private void Rehost(RehostPage intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        var page = Known(intent.PageId);
        Hosting(device.Workspace(page.WorkspaceId), page.SpaceId);
        var engine = engines.Registered(intent.Engine) ?? throw new Rejected(new UnregisteredEngine(intent.Engine));
        if (!ReferenceEquals(engine, page.Engine)) Rehost(page, engine, page.Live.Address, changes, issue);
    }

    /// Closes the page on its engine, keeping nothing, and creates it on
    /// `engine`, which loads `address` once it has created it.
    private void Rehost(Page page, Engine engine, string? address, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        if (page.Phase.HoldsEnginePage) issue(page.Engine, new ClosePage(page.Id, KeepsState: false));
        Update(page, changes, () => page.Rehost(engine, address));
        issue(engine, new CreatePage(page.Id, page.ProfileId, device.Workspace(page.WorkspaceId).IsPrivateBrowsing, page.WindowId,
            RestoreState: null));
    }

    /// The registered engine chosen for the site `tab` shows, or null when
    /// none is, or for a page without a tab, which opens before it has an
    /// address.
    private Engine? Chosen(SpaceState space, TabState? tab) => tab?.Url is { } url ? Chosen(space, url) : null;

    /// The registered engine chosen in `space` for the site `url` belongs to,
    /// or null when none is.
    private Engine? Chosen(SpaceState space, string url) =>
        new WebAddress(url).Origin is { } origin && device.ChosenEngine(space.Id, origin) is { } kind ? engines.Registered(kind) : null;

    private void LeaveFailure(LeavePageFailure intent, ChangeFeed changes) {
        var page = Known(intent.PageId);
        Update(page, changes, page.LeaveFailure);
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
    public void Report(Engine engine, EngineEvent report, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        if (report is PageClosed closedKeeping && keeping.Remove(closedKeeping.PageId, out var kept) && ReferenceEquals(kept.Engine, engine)
            && closedKeeping.RestoreState is { } restoreState)
            Keep((kept.WorkspaceId, kept.TabId), kept.SpaceId, engine.Kind, restoreState);
        var pageId = report switch {
            PageCreated created => created.PageId,
            PageCreationFailed failed => failed.PageId,
            PageClosed closed => closed.PageId,
            NavigationStarted started => started.PageId,
            NavigationCommitted committed => committed.PageId,
            NavigationFinished finished => finished.PageId,
            NavigationFailed failed => failed.PageId,
            PageIconChanged icon => icon.PageId,
            PageStateChanged state => state.PageId,
            PageCrashed crashed => crashed.PageId,
            _ => throw new ArgumentOutOfRangeException(nameof(report), report.GetType().Name, "Pages do not handle this report.")
        };
        if (!open.TryGetValue(pageId, out var page) || !ReferenceEquals(page.Engine, engine)) return;
        switch (report) {
            case PageCreated:
                Enter(page, PagePhase.Live, changes);
                if (page.TakeRehostedAddress() is { } address) issue(page.Engine, new LoadPage(page.Id, address));
                break;
            case PageCreationFailed: Enter(page, PagePhase.Failed, changes); break;
            case PageClosed: Enter(page, PagePhase.Closed, changes); break;
            // A navigation to another document of a site chosen for another
            // registered engine moves the page there, which loads it instead.
            // Otherwise nothing is recorded until the navigation finishes.
            case NavigationStarted { SameDocument: false } started
                when device.Attached(page.WorkspaceId) is { } workspace && !workspace.IsDeleting(page.SpaceId)
                    && workspace.Current.Spaces.FirstOrDefault(space => space.Id == page.SpaceId) is { } space
                    && !workspace.IsLocked(space) && Chosen(space, started.Url) is { } chosen && !ReferenceEquals(chosen, page.Engine):
                Rehost(page, chosen, started.Url, changes, issue);
                break;
            case NavigationStarted: break;
            case NavigationCommitted committed:
                Update(page, changes, () => page.Commit(committed.Url, committed.SameDocument));
                break;
            case NavigationFinished finished when page.Finish(finished.Url):
                Edit(page, new NavigationRecord(page.Id, page.SpaceId, clock.Now, page.TabId, finished.Url, finished.Title, page.Icon,
                    ids.Next()), changes);
                break;
            case NavigationFinished: break;
            case NavigationFailed failed: Update(page, changes, () => page.Fail(failed.Failure)); break;
            case PageIconChanged reported when page.ShowIcon(new(reported.Url, reported.Accent)) && page.TabId is { } tabId:
                Edit(page, new IconAdoption(page.Id, page.SpaceId, clock.Now, tabId, page.Icon!), changes);
                break;
            case PageIconChanged: break;
            case PageStateChanged reported: Update(page, changes, () => page.Show(reported.Snapshot)); break;
            case PageCrashed crashed when page.Phase == PagePhase.Live:
                var recovers = false;
                Update(page, changes, () => recovers = page.Crash(IsShown(page), crashed.Domain, crashed.Code));
                if (recovers) issue(page.Engine, new RecoverPage(page.Id));
                break;
            case PageCrashed: break;
        }
    }

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
    /// platform gives back at `level`.
    private void Relieve(MemoryPressureLevel level, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        Stamp(clock.Now);
        const PageMediaActivity keepsLoaded = PageMediaActivity.Playing | PageMediaActivity.Capturing | PageMediaActivity.PictureInPicture;
        var candidates = open.Values
            .Where(page => page.TabId is not null && page.Phase == PagePhase.Live && page.HiddenSince is not null
                && page.Live.Url is not null && page.Engine.Supports(EngineCapability.PageResidency)
                && (page.Live.Media & keepsLoaded) == 0
                && Tab(page) is { KeepsPageLoaded: false })
            .OrderBy(page => page.HiddenSince).ThenBy(page => page.Id)
            .Take(PageResidencyPolicy.MaximumCandidates)
            .ToDictionary(page => page.Id.ToString(), page => page);
        var plan = PageResidencyPolicy.ReleasePlan(
            [.. candidates.Select(entry => new ResidencyCandidate(entry.Key, entry.Value.HiddenSince!.Value.ToUnixTimeMilliseconds() / 1000.0,
                KeepsPageLoaded: false, IsPresented: false, PresentedIndex: null))],
            level, device.Platform, focusedIndex: null);
        int limit = PageResidencyPolicy.ReleaseLimit(level, plan.OffScreen.Count, device.Platform);
        foreach (var candidate in plan.OffScreen.Take(limit)) {
            var page = candidates[candidate];
            open.Remove(page.Id);
            changes.Publish(new PageRemoved(page.Id));
            changes.Publish(new PageUnloaded(page.Id, page.WorkspaceId, page.TabId!.Value));
            Close(page, keepsState: true, issue);
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
