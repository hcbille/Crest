import Foundation
import Observation
import WebKit

/// The pages the core opened for a workspace's tabs and transient requests
/// that this platform hosts: each tab's page while it stays resident, the
/// Quick Window and Peek pages leased for a while, and the state a tab's page
/// leaves behind when it goes. The core decides which pages open, move and
/// unload; windows present what the host keeps. Every window over one
/// workspace on the Mac shares its host; a phone or tablet scene has its own.
@Observable
@MainActor
final class BrowserPageHost {
    // MARK: - Types

    /// One Peek's lease, kept while the Peek asks for the same request.
    private typealias PeekLease = (request: BrowserPeekRequest, lease: BrowserPlatformTransientPageLease)

    // MARK: - Variables

    /// Each tab's resident page.
    @ObservationIgnored var runtimes: [TabID: BrowserTabRuntime] = [:]
    /// Moves whenever a tab gains or loses its page, for what reads residency.
    var revision = 0
    /// Where tabs' pages leave their engine state when they go.
    let tabState: BrowserTabStateCoordinator
    let nativeTabs = BrowserNativeTabStore()
    /// The Spaces whose pages are being let go or whose data is being deleted.
    @ObservationIgnored var spacesReleasingData: Set<SpaceID> = []
    @ObservationIgnored var spacesDeletingData: Set<SpaceID> = []
    /// Takes a tab's card off every window that presents it, once its page or
    /// native content went.
    @ObservationIgnored var dropPresentation: @MainActor (TabID) -> Void = { _ in }
    @ObservationIgnored private(set) var transientLeases: [UUID: WeakBrowserTransientPageLease] = [:]
    @ObservationIgnored private var peekLeases: [UUID: PeekLease] = [:]

    // MARK: - Initializers

    /// A host whose tabs leave their state in `archive`, or keep none.
    init(archive: (any BrowserTabStateArchiving)? = nil) {
        tabState = BrowserTabStateCoordinator(archive: archive)
    }

    // MARK: - Actions - Resident pages

    /// Every tab's resident page.
    var residentPages: [BrowserPlatformPage] { runtimes.values.map(\.page) }

    /// Every page the host keeps: the tabs' and the leases'.
    var livePages: [BrowserPlatformPage] {
        runtimes.values.flatMap(\.allPages) + transientLeases.values.compactMap { $0.value?.page }
    }

    /// The tab's resident page.
    func page(for tabID: TabID) -> BrowserPlatformPage? {
        runtimes[tabID]?.page
    }

    /// The tab's resident page while it belongs to the Space and profile
    /// `assignment` names.
    func page(matching assignment: BrowserTabRuntimeAssignment) -> BrowserPlatformPage? {
        guard let page = runtimes[assignment.tabID]?.page, page.spaceID == assignment.spaceID,
            page.profileID == assignment.profileID
        else { return nil }
        return page
    }

    /// The tab whose resident page `page` is.
    func tabID(for page: BrowserPlatformPage) -> TabID? {
        runtimes.first { $0.value.page === page }?.key
    }

    /// Keeps `page` as the tab's resident page.
    func retain(_ page: BrowserPlatformPage, for tabID: TabID) {
        if let runtime = runtimes[tabID] {
            runtime.page = page
        } else {
            runtimes[tabID] = BrowserTabRuntime(page: page)
        }
        revision &+= 1
    }

    /// The icon of the tab's resident page, with the accent its site's theme
    /// gives it; nil when the tab has no page of the Space and profile
    /// `assignment` names, or it went while the icon loaded.
    func pullFavicon(
        for tabID: TabID, matching assignment: BrowserSpaceRuntimeAssignment? = nil
    ) async -> (data: Data, iconAccent: BrowserTabIconAccent?)? {
        guard let page = runtimes[tabID]?.page,
            assignment.map({ page.spaceID == $0.spaceID && page.profileID == $0.profileID }) ?? true,
            let data = await page.pullFavicon(),
            runtimes[tabID]?.page === page
        else { return nil }
        return (data, page.siteThemeIconAccent)
    }

    // MARK: - Actions - Reconciliation

    /// Lets go of the pages of tabs that are gone. Their state is not written
    /// out: whether it is worth keeping is settled by the session sweep, which
    /// can tell an archived tab from a deleted one.
    func reconcile(validTabIDs: Set<TabID>) {
        nativeTabs.reconcile(validTabIDs: validTabIDs)
        tabState.retainCopies(for: validTabIDs)
        for tabID in Set(runtimes.keys).subtracting(validTabIDs) {
            evictPage(tabID, preservingTabState: false)
        }
    }

    /// Brings the resident pages in line with `session`: pages whose tab is
    /// gone or moved go, a closed tab's state is kept first, and every page
    /// takes its tab's context and its Space's password preference.
    func reconcile(session: BrowserSession) {
        nativeTabs.reconcile(session: session)
        let reconciliation = BrowserPageReconciliation(
            session: session, residentPages: runtimes.lazy.map { ($0.key, $0.value.page) })
        tabState.retainCopies(matching: reconciliation.validAssignments)
        for tabID in reconciliation.tabIDsToArchive {
            archiveTabState(for: tabID)
        }
        releasePages(for: reconciliation.invalidTabIDs, keepingStateOf: reconciliation.tabIDsToArchive)
        for context in reconciliation.navigationContexts {
            context.page.updateNavigationContext(tab: context.tab)
        }
        tabState.prune(keeping: reconciliation.retainedTabIDsByProfileID)
        reconcileCredentialAccess(in: session)
    }

    /// Brings every resident and leased page in line with its Space's "save
    /// passwords" preference: a background tab can hold a pending save offer,
    /// and a Peek runs a page with no tab of its own.
    func reconcileCredentialAccess(in session: BrowserSession) {
        let enabledBySpaceID = Dictionary(
            uniqueKeysWithValues: session.spaces.map { ($0.id, $0.credentialPreferences.isEnabled) })
        for page in runtimes.values.lazy.map(\.page) {
            page.setCredentialAccessEnabled(enabledBySpaceID[page.spaceID] ?? false)
        }
        pruneTransientLeases()
        for lease in transientLeases.values.compactMap(\.value) {
            lease.setCredentialAccessEnabled(enabledBySpaceID[lease.spaceID] ?? false)
        }
    }

    /// Gives each resident page its tab's current context, such as its icon.
    func reconcileTabIcons(in session: BrowserSession) {
        let tabsByID = Dictionary(
            uniqueKeysWithValues: session.spaces.flatMap { space in space.tabs.map { ($0.id, $0) } })
        for (tabID, runtime) in runtimes {
            guard let tab = tabsByID[tabID] else { continue }
            runtime.page.updateNavigationContext(tab: tab)
        }
    }

    /// Gives every page the host keeps the new default zoom.
    func defaultPageZoomDidChange(to zoom: CGFloat) {
        var visited: Set<ObjectIdentifier> = []
        for page in livePages where visited.insert(ObjectIdentifier(page)).inserted {
            page.applyDefaultPageZoom(zoom)
        }
    }

    // MARK: - Actions - Tab state

    /// Writes out the engine state of the resident pages `includes` names.
    /// The app calls this when a scene stops being active, so state survives
    /// a termination before an inactive page is unloaded.
    func archiveResidentTabStates(where includes: (BrowserTabRuntime) -> Bool = { _ in true }) {
        guard tabState.archivesResidentPages else { return }
        for (tabID, runtime) in runtimes where includes(runtime) {
            archiveTabState(for: tabID)
        }
    }

    func flushPendingTabStateWrites() async {
        await tabState.flushPendingWrites()
    }

    /// Keeps the engine state of the tab's resident page. Capture stays on the
    /// main actor; the archive schedules disk writes.
    func archiveTabState(for tabID: TabID) {
        guard let page = runtimes[tabID]?.page else { return }
        tabState.archivePage(page, for: tabID)
    }

    /// The engine state `tab` left in its Space and profile, when it still
    /// shows `url`.
    func archivedInteractionState(
        for tab: BrowserTab, spaceID: SpaceID, profileID: UUID, expecting url: URL, consumePendingCopy: Bool = true
    ) -> Data? {
        tabState.interactionState(
            for: BrowserTabRuntimeAssignment(tabID: tab.id, spaceID: spaceID, profileID: profileID),
            expecting: url, consumePendingCopy: consumePendingCopy)
    }

    func discardArchivedTabState(matching assignment: BrowserTabRuntimeAssignment) {
        tabState.discardState(matching: assignment)
    }

    // MARK: - Actions - Tab copies

    /// `source` as its resident page shows it now.
    func sourceForTabCopy(_ source: BrowserTab, in space: BrowserSpace) -> BrowserTab {
        var observed = source
        if let page = page(matching: BrowserTabRuntimeAssignment(space: space, tabID: source.id)) {
            observed.url = page.live.displayURL ?? source.url
            if !page.live.title.isEmpty { observed.title = page.live.title }
        }
        return observed
    }

    /// Gives `copy` what `source` shows now, and the engine state its page
    /// keeps for the copy's first page.
    func prepareTabCopy(from source: BrowserTab, to copy: inout BrowserTab, in space: BrowserSpace) {
        let state: Data?
        if let page = page(matching: BrowserTabRuntimeAssignment(space: space, tabID: source.id)) {
            copy.url = page.live.displayURL ?? source.url
            if !page.live.title.isEmpty { copy.title = page.live.title }
            state = !page.wasOpenedAsPopup && page.live.documentURL == copy.url ? page.interactionState : nil
        } else if let url = source.url {
            state = archivedInteractionState(
                for: source, spaceID: space.id, profileID: space.profile.id, expecting: url, consumePendingCopy: false)
        } else {
            state = nil
        }
        guard let state else { return }
        tabState.prepareCopy(state, url: copy.url, for: BrowserTabRuntimeAssignment(space: space, tabID: copy.id))
    }

    /// The address the tab's resident page shows.
    func liveLinkURL(for assignment: BrowserTabRuntimeAssignment) -> URL? {
        page(matching: assignment)?.live.documentURL
    }

    // MARK: - Actions - Unloading

    /// Unloads the tab's page and native content, keeping its engine state
    /// when `preservingTabState`: a tab unloaded by hand comes back where it
    /// was left. Its card goes with it.
    func unloadPage(for tabID: TabID, preservingTabState: Bool = true) {
        if nativeTabs.tabIDs.contains(tabID) {
            nativeTabs.remove(tabID)
            dropPresentation(tabID)
        }
        if preservingTabState { archiveTabState(for: tabID) }
        guard let runtime = runtimes.removeValue(forKey: tabID) else { return }
        runtime.release(keepingState: preservingTabState)
        dropPresentation(tabID)
        revision &+= 1
    }

    /// Unloads the tab's page while it belongs to the Space and profile
    /// `assignment` names; false when it does not.
    @discardableResult
    func unloadPage(for tabID: TabID, matching assignment: BrowserSpaceRuntimeAssignment) -> Bool {
        let tab = BrowserTabRuntimeAssignment(tabID: tabID, spaceID: assignment.spaceID, profileID: assignment.profileID)
        if nativeTabs.contains(tab) {
            unloadPage(for: tabID)
            return true
        }
        guard page(matching: tab) != nil else { return false }
        unloadPage(for: tabID)
        return true
    }

    /// Closes the tab's page for good. It differs from an unload only when
    /// the person chose to return to the saved address on the next open,
    /// which drops the state the page left.
    func closeDurablePage(_ assignment: BrowserTabRuntimeAssignment, discardState: Bool) -> Bool {
        guard !nativeTabs.tabIDs.contains(assignment.tabID) || nativeTabs.contains(assignment) else { return false }
        guard
            runtimes[assignment.tabID].map({
                $0.page.spaceID == assignment.spaceID && $0.page.profileID == assignment.profileID
            }) ?? true
        else { return false }
        unloadPage(for: assignment.tabID, preservingTabState: !discardState)
        if discardState { discardArchivedTabState(matching: assignment) }
        return true
    }

    /// Releases a Space's resident and leased pages without keeping their
    /// state. Switching or locking a Space keeps its pages resident.
    func unloadPages(in spaceID: SpaceID) {
        let nativeTabIDs = nativeTabs.tabIDs(in: spaceID)
        nativeTabs.remove(in: spaceID)
        let tabIDs = Set(runtimes.compactMap { $0.value.page.spaceID == spaceID ? $0.key : nil })
        releasePages(for: tabIDs.union(nativeTabIDs))
        releaseTransientPages(in: spaceID)
    }

    /// Lets go of the tab's page and native content, keeping its engine state
    /// when `preservingTabState`.
    func evictPage(_ tabID: TabID, preservingTabState: Bool = true) {
        nativeTabs.remove(tabID)
        dropPresentation(tabID)
        if preservingTabState { archiveTabState(for: tabID) }
        guard let runtime = runtimes.removeValue(forKey: tabID) else { return }
        runtime.release(keepingState: preservingTabState)
        revision &+= 1
    }

    /// Releases the pages of `tabIDs`, saying for `kept` that their state was
    /// archived first, and answers what shows each page went.
    @discardableResult
    func releasePages(
        for tabIDs: Set<TabID>, keepingStateOf kept: Set<TabID> = []
    ) -> [BrowserSpaceDataReleaseProbe] {
        var releasedAnyPage = false
        var probes: [BrowserSpaceDataReleaseProbe] = []
        for tabID in tabIDs {
            let runtime = runtimes.removeValue(forKey: tabID)
            dropPresentation(tabID)
            guard let runtime else { continue }
            probes.append(contentsOf: runtime.allPages.map { BrowserSpaceDataReleaseProbe($0) })
            runtime.release(keepingState: kept.contains(tabID))
            releasedAnyPage = true
        }
        if releasedAnyPage { revision &+= 1 }
        return probes
    }

    /// The core unloaded the tab's page under memory pressure and closed what
    /// its engine held. TRANSITIONAL until WebKit's close hands the core its
    /// restore state: a WebKit page's state is kept from its web view here
    /// first, with the web view's own address, since the core no longer holds
    /// the page's.
    func pageUnloaded(_ unloaded: PageUnloaded) {
        let tabID = unloaded.tabID
        guard let runtime = runtimes[tabID], runtime.page.corePage.id == unloaded.pageID else { return }
        let page = runtime.page
        if !page.pageEngine.registration.handsRestoreStateToCore {
            tabState.archivePage(page, showing: page.webKitView?.url, for: tabID)
        }
        runtimes.removeValue(forKey: tabID)
        dropPresentation(tabID)
        runtime.unloaded()
        revision &+= 1
    }

    /// Releases what memory pressure takes back that the core does not decide:
    /// leased pages, only inactive ones on a warning, and on critical pressure
    /// the native content of tabs no window shows. The core unloads tabs'
    /// pages itself once the platform reports the pressure.
    func relieveMemoryPressure(_ level: MemoryPressureLevel, presenting presented: [TabID]) {
        releaseTransientPages(for: level)
        guard level == .critical else { return }
        for tabID in nativeTabs.inactiveTabIDs(excluding: presented) {
            evictPage(tabID)
        }
    }

    // MARK: - Actions - Data

    /// Lets go of every page of `space` or its profile, and of its native
    /// content, and waits until nothing shows them.
    func releasePages(of space: BrowserSpace) async {
        let nativeTabIDs = nativeTabs.tabIDs(in: space.id)
        nativeTabs.remove(in: space.id)
        let tabIDs = Set(
            runtimes.compactMap { tabID, runtime in
                runtime.page.spaceID == space.id || runtime.page.profileID == space.profile.id ? tabID : nil
            }
        ).union(nativeTabIDs)
        let probes = releasePages(for: tabIDs) + releaseTransientPages(in: space.id)
        await BrowserSpaceDataReleaseBarrier.waitForRetainedViews(probes)
    }

    /// Deletes what the host keeps of `space` before the Space goes: `release`
    /// lets go of its pages and what the platform keeps besides, then every
    /// engine erases its profile through `core`, `ephemeral` when this launch
    /// keeps it in memory only. Throws when an engine could not erase it.
    func deleteData(
        for space: BrowserSpace, on core: CrestCore, ephemeral: Bool, release: () async -> Void
    ) async throws {
        guard spacesDeletingData.insert(space.id).inserted else { return }
        defer { spacesDeletingData.remove(space.id) }
        await release()
        await BrowserFaviconFallbackLoader.shared.removeAll(for: space.profile.id)
        // Nothing may outlive the profile it describes.
        tabState.removeStates(profileID: space.profile.id)
        // Every engine erases the profile, started or not; the Space's
        // deletion finishes only once each has.
        let erased = await core.deleteData(
            DeleteProfileData(requestID: UUID(), profileID: space.profile.id, ephemeral: ephemeral))
        guard erased else { throw BrowserSpaceDeletionError.dataNotErased }
    }

    /// Lets go of every page a private workspace kept.
    func closePrivateBrowsingSession() {
        releasePages(for: Set(runtimes.keys).union(nativeTabs.tabIDs))
        nativeTabs.reconcile(validTabIDs: [])
        releaseAllTransientPages()
    }

    // MARK: - Actions - Leases

    var retainedTransientPageCount: Int {
        pruneTransientLeases()
        return transientLeases.values.compactMap(\.value).filter { $0.page != nil }.count
    }

    /// A lease on a page the core opens in `space` for a transient request
    /// presenting as `presentation`, which loads `url` and rebuilds its page
    /// from `makePage` after memory pressure. Only the first page replays
    /// `engineNavigation`. Nil when the core refuses the page.
    func makeTransientPageLease(
        url: URL, in space: BrowserSpace, presentation: TransientPresentation,
        engineNavigation: BrowserEngineNavigation?, balancedContentRuleLists: [WKContentRuleList],
        onUserActivity: @escaping () -> Void, onDownloadOnlyNavigation: (() -> Void)?,
        makePage: @escaping @MainActor () -> BrowserPlatformPage?
    ) -> BrowserPlatformTransientPageLease? {
        // The core decides whether the Space may host a page, for the first
        // page and for every page memory pressure makes the lease rebuild.
        guard let initialPage = makePage() else { return nil }
        if let engineNavigation, !initialPage.pageEngine.stageNavigation(engineNavigation, expecting: url) {
            initialPage.release(keepingState: false)
            return nil
        }
        let lease = BrowserPlatformTransientPageLease(
            page: initialPage, url: url, contentBlockingPolicy: space.browsingPreferences.contentBlockingPolicy,
            balancedContentRuleLists: balancedContentRuleLists, rebuild: makePage, userActivity: onUserActivity,
            onDownloadOnlyNavigation: onDownloadOnlyNavigation)
        transientLeases[lease.id] = WeakBrowserTransientPageLease(lease)
        return lease
    }

    /// The Peek's lease for `request`: the one it already holds while it can
    /// still show its page, or a new one `makeLease` opens.
    func peekPageLease(
        for request: BrowserPeekRequest,
        makeLease: () -> BrowserPlatformTransientPageLease?
    ) -> BrowserPlatformTransientPageLease? {
        if let entry = peekLeases[request.id], entry.request == request,
            case let lease = entry.lease, lease.assignment == request.assignment,
            lease.page != nil || lease.wasReleasedForMemoryPressure
        {
            return lease
        }
        peekLeases.removeValue(forKey: request.id)?.lease.release()
        let lease = makeLease()
        if let lease { peekLeases[request.id] = (request, lease) }
        return lease
    }

    /// Lets go of the Peeks' leases no longer asked for.
    func retainPeekPages(for requests: [BrowserPeekRequest]) {
        for (id, entry) in peekLeases where !requests.contains(entry.request) {
            peekLeases.removeValue(forKey: id)?.lease.release()
        }
    }

    /// Takes the page `lease` holds for tab `tabID` of `space`, once `prepare`
    /// readied it and the core gave it to the tab through `browser`; nil when
    /// the lease holds no page of that Space, or either refused.
    func adoptTransientPage(
        _ lease: BrowserPlatformTransientPageLease, as tabID: TabID, in space: BrowserSpace, through browser: BrowserStore,
        prepare: (BrowserPlatformPage) -> Bool
    ) -> BrowserPlatformPage? {
        guard let page = lease.page else { return nil }
        let assignment = BrowserSpaceRuntimeAssignment(space: space)
        guard lease.assignment == assignment, page.spaceID == assignment.spaceID,
            page.profileID == assignment.profileID, prepare(page),
            // The core gives the tab the page only while the tab has none.
            browser.adoptPage(page.corePage, in: space.id, as: tabID)
        else { return nil }
        guard lease.relinquishPage() === page else {
            _ = browser.adoptPage(page.corePage, in: space.id, as: nil)
            return nil
        }
        transientLeases.removeValue(forKey: lease.id)
        return page
    }

    /// Ends the lease holding `page` when its only navigation turned out to
    /// be a download; false when no lease holds it or the lease keeps it.
    func discardDownloadOnlyTransientPage(_ page: BrowserPlatformPage) -> Bool {
        guard let entry = transientLeases.first(where: { $0.value.value?.page === page }),
            let lease = entry.value.value, lease.discardForDownloadOnlyNavigation()
        else { return false }
        transientLeases.removeValue(forKey: entry.key)
        return true
    }

    /// Whether a lease holds `page`.
    func leases(_ page: BrowserPlatformPage) -> Bool {
        transientLeases.values.contains { $0.value?.page === page }
    }

    /// Every live lease.
    var liveTransientLeases: [BrowserPlatformTransientPageLease] {
        pruneTransientLeases()
        return transientLeases.values.compactMap(\.value)
    }

    func releaseTransientPages(for level: MemoryPressureLevel) {
        for lease in liveTransientLeases where level.releasesActiveTransientPages || !lease.isActive {
            lease.releaseForMemoryPressure()
        }
    }

    @discardableResult
    func releaseTransientPages(in spaceID: SpaceID) -> [BrowserSpaceDataReleaseProbe] {
        pruneTransientLeases()
        var probes: [BrowserSpaceDataReleaseProbe] = []
        for (id, weakLease) in transientLeases where weakLease.value?.spaceID == spaceID {
            if let page = weakLease.value?.page { probes.append(BrowserSpaceDataReleaseProbe(page)) }
            weakLease.value?.release()
            transientLeases.removeValue(forKey: id)
        }
        return probes
    }

    func releaseAllTransientPages() {
        for lease in transientLeases.values.compactMap(\.value) {
            lease.release()
        }
        transientLeases.removeAll()
        peekLeases.removeAll()
    }

    func pruneTransientLeases() {
        transientLeases = transientLeases.filter { $0.value.value != nil }
    }
}

extension BrowserTabRuntimeAssignment {
    /// Tab `tabID` of `space`, in its profile.
    init(space: BrowserSpace, tabID: TabID) {
        self.init(tabID: tabID, spaceID: space.id, profileID: space.profile.id)
    }
}
