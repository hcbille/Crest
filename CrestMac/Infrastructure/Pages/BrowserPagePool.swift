import AppKit
import Foundation
import Observation
import os

@Observable
@MainActor
final class BrowserPagePool:
    BrowserSpaceDataDeleting,
    BrowserPageHosting,
    BrowserDefaultPageZoomObserving
{

    @ObservationIgnored private static let lifecycleSignposter = OSSignposter(
        subsystem: "com.pauldavis.crest",
        category: "WebKitLifecycle"
    )

    typealias HTTPAuthenticationCredentialLoader =
        @MainActor (
            BrowserHTTPAuthenticationProtectionSpace,
            SpaceID
        ) async throws -> BrowserCredential?

    typealias HTTPAuthenticationCredentialSaver =
        @MainActor (
            BrowserHTTPAuthenticationSaveRequest,
            SpaceID
        ) async throws -> Void

    typealias ModifiedLinkOpener =
        @MainActor (URL, SpaceID, Bool) -> BrowserModifiedLinkRegistration?

    /// The focused card: the one tab the URL bar, navigation controls, find,
    /// zoom, sharing, and every lifecycle observer speak for. Split View adds
    /// cards beside it without adding a second focus.
    private(set) var activeTabID: TabID? {
        willSet {
            if let activeTabID, activeTabID != newValue,
                tabRuntimes[activeTabID]?.presentationWindowID == windowID,
                !runtimeStore.isPresented(activeTabID, outside: windowID)
            {
                activePage?.translation.suspend()
            }
        }
    }

    /// Every card the content area is presenting, in session member order.
    ///
    /// Derived from `BrowserSpace.presentedSplitMembers(for:)` — the same
    /// source the sidebar folds its group row from, so the two can never
    /// disagree about who is on screen. A tab outside a renderable split
    /// presents alone, which is one element rather than a special case, and
    /// `activeTabID` is always a member while anything is presented.
    ///
    /// Deliberately observable: a card mount reads it through
    /// `presentedPage(for:)` and has to re-render when membership changes.
    private(set) var presentedTabIDs: [TabID] = [] {
        didSet { runtimeStore.updatePresentation(of: self) }
    }
    private(set) var residencyRevision: Int {
        get { runtimeStore.revision }
        set { runtimeStore.revision = newValue }
    }
    let runtimeStore: BrowserPageRuntimeStore
    /// The window this pool hosts pages for. Its pages open through the core
    /// from this window, in its workspace.
    @ObservationIgnored let browser: BrowserStore
    var windowID: BrowserWindowID { browser.windowID }
    @ObservationIgnored private weak var presentationWindow: NSWindow?
    private(set) var isWindowFocused = true
    var publishesPageMetadataCentrally: Bool { runtimeStore.publishesPageMetadataCentrally }
    var contentBlockingErrorDescription: String? { contentBlocking.errorDescription }
    let downloadCenter: BrowserDownloadCenter
    /// Mirrors the runtime's console capture: web pages then report their
    /// calls into an installed extension to the diagnostics log.
    let permissionCenter: BrowserSitePermissionCenter
    var serverTrustOverrides: BrowserServerTrustOverrideStore { profileDataStores.serverTrustOverrides }

    /// Each tab owns its current and suspended configurations, including the
    /// history links that bridge ordinary pages and extension origins.
    private var tabRuntimes: [TabID: BrowserTabRuntime] {
        get { runtimeStore.runtimes }
        set { runtimeStore.runtimes = newValue }
    }
    /// Per-profile engine state every window pool of this store family shares.
    @ObservationIgnored let profileDataStores: BrowserPageProfileDataStores
    @ObservationIgnored private let contentRuleListProvider: any BrowserContentRuleListProviding
    /// The app's passkey access, refreshed as pages navigate. Nil where no
    /// composition supplied one.
    @ObservationIgnored private let passkeyAccess: BrowserPasskeyAccessController?
    @ObservationIgnored private let browsingMode: BrowserBrowsingMode
    @ObservationIgnored let usesEphemeralWebsiteDataStores: Bool
    @ObservationIgnored private let pageZoomPreferences: BrowserDefaultPageZoomStore
    @ObservationIgnored private let dialogPresenter: BrowserDialogPresenter
    @ObservationIgnored private let popupTabHost: BrowserPopupTabHost
    @ObservationIgnored private let openNewTab: (URL) -> Void
    @ObservationIgnored private let openModifiedLink: ModifiedLinkOpener
    @ObservationIgnored private let openPeek: (BrowserPeekRequest) -> Void
    @ObservationIgnored private let handleLinkDrag: (BrowserPeekInteractionEvent) -> Void
    @ObservationIgnored private let splitLinkHost: BrowserSplitLinkHost
    @ObservationIgnored let linkDestinationHost: BrowserLinkDestinationHost
    @ObservationIgnored private let hostedNotificationCenter: (any BrowserHostedWebNotificationCentering)?
    @ObservationIgnored private let mediaSessionStore: BrowserMediaSessionStore?
    @ObservationIgnored private var selectPictureInPictureSource:
        (BrowserTabRuntimeAssignment) -> BrowserPresentedSession? = {
            _ in nil
        }
    @ObservationIgnored private let activateHostedNotificationSource: (SpaceID, TabID) -> Void
    @ObservationIgnored private let loadHTTPAuthenticationCredential: HTTPAuthenticationCredentialLoader
    @ObservationIgnored private let saveHTTPAuthenticationCredential: HTTPAuthenticationCredentialSaver
    /// Built-in content blocking, which only the WebKit engine applies.
    @ObservationIgnored let contentBlocking: BrowserContentBlockingController
    /// The pages every window over this workspace shares: tabs', leases' and
    /// the state tabs leave when their pages go.
    var host: BrowserPageHost { runtimeStore.host }

    init(
        browser: BrowserStore,
        runtimeStore: BrowserPageRuntimeStore? = nil,
        profileDataStores: BrowserPageProfileDataStores? = nil,
        browsingMode: BrowserBrowsingMode = .standard,
        usesEphemeralWebsiteDataStores: Bool =
            BrowserLaunchEnvironment.current.usesEphemeralProfileStorage,
        pageZoomPreferences: BrowserDefaultPageZoomStore = .shared,
        permissionCenter: BrowserSitePermissionCenter = BrowserSitePermissionCenter(),
        hostedNotificationCenter:
            (any BrowserHostedWebNotificationCentering)? = nil,
        mediaSessionStore: BrowserMediaSessionStore? = nil,
        downloadCenter: BrowserDownloadCenter? = nil,
        passkeyAccess: BrowserPasskeyAccessController? = nil,
        loadHTTPAuthenticationCredential:
            @escaping HTTPAuthenticationCredentialLoader = { _, _ in nil },
        saveHTTPAuthenticationCredential:
            @escaping HTTPAuthenticationCredentialSaver = { _, _ in },
        contentRuleListProvider: (any BrowserContentRuleListProviding)? = nil,
        tabStateArchive: (any BrowserTabStateArchiving)? = nil,
        popupTabHost: BrowserPopupTabHost = .unavailable,
        openNewTab: @escaping (URL) -> Void = { _ in },
        openModifiedLink: @escaping ModifiedLinkOpener = { _, _, _ in nil },
        openPeek: @escaping (BrowserPeekRequest) -> Void = { _ in },
        handleLinkDrag: @escaping (BrowserPeekInteractionEvent) -> Void = { _ in },
        splitLinkHost: BrowserSplitLinkHost = .unavailable,
        linkDestinationHost: BrowserLinkDestinationHost = .unavailable,
        activateHostedNotificationSource:
            @escaping (SpaceID, TabID) -> Void = { _, _ in }
    ) {
        let dialogPresenter = BrowserDialogPresenter()
        let core = browser.core
        self.browser = browser
        self.browsingMode = browsingMode
        self.usesEphemeralWebsiteDataStores =
            usesEphemeralWebsiteDataStores || browsingMode.isPrivate
        self.pageZoomPreferences = pageZoomPreferences
        let owner =
            runtimeStore
            ?? BrowserPageRuntimeStore(
                archive: self.usesEphemeralWebsiteDataStores ? nil : tabStateArchive
            )
        self.runtimeStore = owner
        self.profileDataStores = profileDataStores ?? BrowserPageProfileDataStores()
        let contentRuleListProvider =
            contentRuleListProvider ?? BrowserContentRuleListProvider.forLaunch(core: core)
        self.contentRuleListProvider = contentRuleListProvider
        self.passkeyAccess = passkeyAccess
        self.permissionCenter = permissionCenter
        self.hostedNotificationCenter = hostedNotificationCenter
        self.mediaSessionStore = browsingMode.isPrivate ? nil : mediaSessionStore
        self.dialogPresenter = dialogPresenter
        self.popupTabHost = popupTabHost
        self.loadHTTPAuthenticationCredential = loadHTTPAuthenticationCredential
        self.saveHTTPAuthenticationCredential = saveHTTPAuthenticationCredential
        contentBlocking = BrowserContentBlockingController(provider: contentRuleListProvider)
        self.openNewTab = openNewTab
        self.openModifiedLink = openModifiedLink
        self.openPeek = openPeek
        self.handleLinkDrag = handleLinkDrag
        self.splitLinkHost = splitLinkHost
        self.linkDestinationHost = linkDestinationHost
        self.activateHostedNotificationSource = activateHostedNotificationSource
        self.downloadCenter =
            downloadCenter
            ?? BrowserDownloadCenter(
                core: core,
                approveRiskyDownload: { assessment, sourceURL, spaceName, _ in
                    await dialogPresenter.approveRiskyDownload(
                        assessment: assessment,
                        sourceURL: sourceURL,
                        spaceName: spaceName
                    )
                },
                permissionCenter: permissionCenter
            )
        pageZoomPreferences.register(self)
        self.runtimeStore.register(self)
        core.engines.observeRecords(self) { [weak self] in self?.restyleVisitedLinks(after: $0) }
        core.followUnloadedPages(self) { [weak self] in self?.host.pageUnloaded($0) }
    }

    var nativeTabs: BrowserNativeTabStore { runtimeStore.nativeTabs }

    func bindNativeWindow(_ window: NSWindow?) {
        presentationWindow = window
    }

    func setWindowFocused(_ focused: Bool) {
        isWindowFocused = focused
        if focused { runtimeStore.focus(self) }
    }

    func releaseWindowPresentation() {
        presentationWindow = nil
        activeTabID = nil
        presentedTabIDs = []
        runtimeStore.unregister(self)
    }

    func isMirroringPage(for tabID: TabID) -> Bool {
        _ = residencyRevision
        guard presentedTabIDs.contains(tabID), let runtime = tabRuntimes[tabID] else { return false }
        return runtime.presentationWindowID != nil && runtime.presentationWindowID != windowID
    }

    func mirroredPageSnapshot(for tabID: TabID) -> NSImage? {
        _ = residencyRevision
        return tabRuntimes[tabID]?.snapshot
    }

    func claimPresentedPage(for tabID: TabID) {
        runtimeStore.claim(tabID, for: self)
    }

    func removeTransferredPresentation(_ tabID: TabID) {
        presentedTabIDs.removeAll { $0 == tabID }
        if activeTabID == tabID { activeTabID = nil }
    }

    /// The caller commits the matching model move in the same main-actor turn.
    /// No load, teardown or archive may occur while transferring the runtime.
    func transferTabRuntime(
        from source: BrowserPagePool,
        matching assignment: BrowserTabRuntimeAssignment,
        as tab: BrowserTab,
        in space: BrowserSpace
    ) -> Bool {
        guard canTransferTabRuntime(from: source, matching: assignment, as: tab, in: space) else { return false }
        guard source.runtimeStore !== runtimeStore else { return true }
        if source.nativeTabs.contains(assignment) {
            guard source.nativeTabs.transfer(matching: assignment, to: nativeTabs) else { return false }
            source.runtimeStore.removePresentation(of: tab.id)
            return true
        }
        guard let runtime = source.tabRuntimes[tab.id] else {
            if let url = tab.url,
                let state = source.host.archivedInteractionState(
                    for: tab, spaceID: space.id, profileID: space.profile.id, expecting: url)
            {
                host.tabState.prepareCopy(state, url: url, for: assignment)
            }
            source.host.discardArchivedTabState(matching: assignment)
            source.runtimeStore.removePresentation(of: tab.id)
            return true
        }
        // The page keeps its engine page and moves to this window's workspace.
        guard browser.adoptPage(runtime.page.corePage, in: space.id, as: tab.id) else { return false }
        source.tabRuntimes.removeValue(forKey: tab.id)
        source.host.discardArchivedTabState(matching: assignment)
        source.runtimeStore.removePresentation(of: tab.id)
        source.residencyRevision &+= 1
        runtime.presentationWindowID = nil
        runtimeStore.install(runtime, for: tab.id, from: self)
        for page in runtime.allPages {
            page.updateNavigationContext(tab: tab)
        }
        residencyRevision &+= 1
        return true
    }

    func canTransferTabRuntime(
        from source: BrowserPagePool,
        matching assignment: BrowserTabRuntimeAssignment,
        as tab: BrowserTab,
        in space: BrowserSpace
    ) -> Bool {
        // The core's tear-off question already refused a Space being deleted
        // or locked, and moving the page asks the core again.
        guard assignment.tabID == tab.id, assignment.spaceID == space.id,
            assignment.profileID == space.profile.id
        else { return false }
        guard source.runtimeStore !== runtimeStore else { return true }
        guard tabRuntimes[tab.id] == nil, !nativeTabs.tabIDs.contains(tab.id) else { return false }
        if source.nativeTabs.tabIDs.contains(tab.id) { return source.nativeTabs.contains(assignment) }
        guard let runtime = source.tabRuntimes[tab.id] else { return true }
        return runtime.page.spaceID == space.id && runtime.page.profileID == space.profile.id
    }

    /// Temporary windows end the lifetime of their own workspace. Normal
    /// windows only call releaseWindowPresentation and retain shared pages.
    func closeWindowWorkspace() {
        releaseWindowPresentation()
        reconcile(validTabIDs: [])
        host.releaseAllTransientPages()
    }

    func bindRuntimeRouting(_ runtime: BrowserTabRuntime, tabID: TabID) {
        for page in runtime.allPages {
            page.setPrivateBrowsing(browsingMode.isPrivate)
            page.host = self
            page.windowRouting?.pool = self
            page.downloadCenter = downloadCenter
            page.splitLinkHost = splitLinkHost
            page.linkDestinationHost = linkDestinationHost
        }
    }

    func makeWindowPool(
        browser: BrowserStore,
        sharesRuntimes: Bool,
        transientBrowsing: BrowserTransientBrowsingCoordinator,
        spaceAccess: BrowserSpaceAccessController
    ) -> BrowserPagePool {
        let owner = sharesRuntimes ? runtimeStore : BrowserPageRuntimeStore()
        owner.publishesPageMetadataCentrally = true
        let pool = BrowserPagePool(
            browser: browser, runtimeStore: owner, profileDataStores: profileDataStores, browsingMode: browsingMode,
            usesEphemeralWebsiteDataStores: usesEphemeralWebsiteDataStores,
            pageZoomPreferences: pageZoomPreferences,

            permissionCenter: permissionCenter,
            hostedNotificationCenter: hostedNotificationCenter, mediaSessionStore: mediaSessionStore,
            downloadCenter: downloadCenter, passkeyAccess: passkeyAccess,
            loadHTTPAuthenticationCredential: { [weak browser] protectionSpace, spaceID in
                try await browser?.httpAuthenticationCredential(for: protectionSpace, in: spaceID)
            },
            saveHTTPAuthenticationCredential: { [weak browser] request, spaceID in
                try await browser?.saveHTTPAuthenticationCredential(
                    username: request.username, password: request.password, protectionSpace: request.protectionSpace,
                    in: spaceID, replacing: request.replacing)
            },
            contentRuleListProvider: contentRuleListProvider,
            popupTabHost: browser.popupTabHost,
            openNewTab: { [weak browser] url in browser?.openNewTab(url: url) },
            openModifiedLink: { [weak browser] url, spaceID, selecting in
                guard let browser, let tabID = browser.openNewTab(url: url, in: spaceID, selecting: selecting),
                    let space = browser.session.space(id: spaceID),
                    let tab = space.tabs.first(where: { $0.id == tabID })
                else { return nil }
                return BrowserModifiedLinkRegistration(tab: tab, space: space, session: browser.presented)
            },
            openPeek: { [weak transientBrowsing] in transientBrowsing?.presentPeek($0) },
            handleLinkDrag: { [weak transientBrowsing] in transientBrowsing?.handleLinkDrag($0) },
            splitLinkHost: browser.splitLinkHost,
            linkDestinationHost: BrowserLinkDestinationHost(browser: browser, spaceAccess: spaceAccess),
            activateHostedNotificationSource: { [weak browser] spaceID, tabID in
                browser?.selectSpace(spaceID)
                browser?.selectTab(tabID)
            })
        pool.connectPictureInPictureSourceSelection(to: browser, spaceAccess: spaceAccess)
        browser.tabLinkProvider = pool
        browser.tabCopying = pool
        pool.setWindowFocused(false)
        return pool
    }

    /// Connects a directly presented pool to the browser selection it owns.
    func connectPictureInPictureSourceSelection(
        to browser: BrowserStore,
        spaceAccess: BrowserSpaceAccessController
    ) {
        selectPictureInPictureSource = { [weak browser, weak spaceAccess] source in
            guard let browser, let spaceAccess,
                let space = BrowserSidebarAccessPolicy.unlockedSpace(
                    matching: BrowserSpaceRuntimeAssignment(spaceID: source.spaceID, profileID: source.profileID),
                    in: browser, accessController: spaceAccess),
                space.tabs.model(source.tabID) != nil
            else { return nil }
            browser.selectSpace(space.id)
            browser.selectTab(source.tabID)
            return browser.presented
        }
    }

    var retainedTabIDs: Set<TabID> {
        _ = residencyRevision
        return Set(tabRuntimes.keys)
    }

    func containsResidentPage(for tabID: TabID) -> Bool {
        _ = residencyRevision
        return tabRuntimes[tabID]?.page != nil
    }

    func containsResidentPage(
        matching assignment: BrowserTabRuntimeAssignment
    ) -> Bool {
        residentPage(matching: assignment) != nil
    }

    /// Reads an already-resident page for its own Space's chrome without
    /// selecting or loading it. Web content hosts must use presentedPage.
    func residentPage(matching assignment: BrowserTabRuntimeAssignment) -> BrowserPage? {
        _ = residencyRevision
        return host.page(matching: assignment)
    }

    func siteThemeIconAccent(for tabID: TabID) -> BrowserTabIconAccent? {
        host.page(for: tabID)?.siteThemeIconAccent
    }

    func siteThemeIconAccent(
        matching assignment: BrowserTabRuntimeAssignment
    ) -> BrowserTabIconAccent? {
        host.page(matching: assignment)?.siteThemeIconAccent
    }

    var retainedTransientPageCount: Int { host.retainedTransientPageCount }

    /// Every page this window's host keeps, including retained transient
    /// leases. Used to answer "what is under the pointer" without recognising
    /// one engine's view class.
    var livePages: [BrowserPage] {
        _ = residencyRevision
        return host.livePages
    }

    var activePage: BrowserPage? {
        _ = residencyRevision
        guard let activeTabID else { return nil }
        return tabRuntimes[activeTabID]?.page
    }

    /// The resident page of a presented card, or `nil` for a tab that is not
    /// on screen right now.
    ///
    /// Membership is checked rather than residency alone: a background tab can
    /// keep a resident page for as long as memory allows, and handing one to a
    /// card would put a second host on a web view that already has one.
    func presentedPage(for tabID: TabID) -> BrowserPage? {
        _ = residencyRevision
        guard presentedTabIDs.contains(tabID),
            let runtime = tabRuntimes[tabID],
            runtime.presentationWindowID == windowID
        else { return nil }
        return runtime.page
    }

    var canGoBack: Bool { activePage?.live.canGoBack == true }
    var canGoForward: Bool { activePage?.live.canGoForward == true }
    var backHistory: [BrowserNavigationHistoryItem] { activePage?.backHistory ?? [] }
    var forwardHistory: [BrowserNavigationHistoryItem] { activePage?.forwardHistory ?? [] }

    var hasActivePage: Bool {
        activePage?.live.documentURL != nil
    }

    var isLoading: Bool {
        activePage?.live.isLoading == true
    }

    var pageZoomLabel: String {
        BrowserPageZoomPolicy.percentageLabel(for: activePage?.pageZoom ?? 1)
    }

    var readerModeState: BrowserReaderModeState {
        activePage?.readerModeState ?? .unavailable
    }

    var readerModeActionTitle: LocalizedStringResource {
        readerModeState.isActive ? "Hide Reader" : "Show Reader"
    }

    func select(
        tab: BrowserTab?,
        space: BrowserSpace?,
        at time: Date = .now
    ) {
        startInitialNavigations(
            presentCards(tab: tab, space: space, at: time)
        )
    }

    /// Builds and presents the cards `tab` brings on screen without navigating
    /// any of them, answering the cards whose first load is still owed.
    private func presentCards(
        tab: BrowserTab?,
        space: BrowserSpace?,
        at time: Date
    ) -> [(tab: BrowserTab, page: BrowserPage)] {
        let interval = Self.lifecycleSignposter.beginInterval("Select Browser Page")
        defer {
            Self.lifecycleSignposter.endInterval("Select Browser Page", interval)
        }

        guard let space else {
            deactivatePagePresentation()
            return []
        }
        guard let tab else {
            leavePagePresentation()
            return []
        }
        // Every member of the selected tab's split group is a live card, so
        // each one is built and started here. A card the person can see must
        // never wait for focus to load: lazy loading is for tabs off screen.
        let members = presentedMembers(for: tab, in: space)
        // Ask the departing engine while its view is still attached. Creating
        // the destination page can hide the previous native surface first.
        requestAutomaticPictureInPicture(forDeparturesBefore: members.map(\.id))
        for member in members { nativeTabs.load(tab: member, space: space, at: time) }
        // A card the core refuses a page, such as one in a locked Space,
        // presents without one.
        let memberPages = members.filter { $0.nativeContent == nil }.compactMap { member in
            page(for: member, space: space).map { (tab: member, page: $0) }
        }
        activate(tab.id, presenting: members.map(\.id))
        return memberPages
    }

    private func startInitialNavigations(
        _ cards: [(tab: BrowserTab, page: BrowserPage)]
    ) {
        for card in cards {
            loadInitialURL(for: card.tab, into: card.page)
        }
    }

    private func openModifiedLink(
        _ request: URLRequest,
        in spaceID: SpaceID,
        selecting: Bool
    ) {
        guard let url = request.url,
            let registration = openModifiedLink(url, spaceID, selecting),
            let page = page(for: registration.tab, space: registration.space)
        else {
            return
        }
        page.load(request)
        if selecting { select(session: registration.session) }
        reconcileCredentialAccess(in: registration.session.session)
    }

    /// The cards `tab` brings on screen, with the caller's own tab value in
    /// place of the Space's copy of it.
    ///
    /// Selection can hand over a tab the store has already moved on from — a
    /// restored saved location, say — and that fresher value is the one whose
    /// URL the initial load has to use. A tab the Space does not carry at all
    /// presents alone rather than not at all.
    private func presentedMembers(
        for tab: BrowserTab,
        in space: BrowserSpace
    ) -> [BrowserTab] {
        let members = space.presentedSplitMembers(for: tab.id)
        guard members.contains(where: { $0.id == tab.id }) else { return [tab] }
        return members.map { $0.id == tab.id ? tab : $0 }
    }

    /// Presents what the window selects. `session` pairs the core's data with
    /// that window's own selection.
    func select(session: BrowserPresentedSession) {
        select(session: session, at: .now)
    }

    func select(session: BrowserPresentedSession, at time: Date) {
        let cards = presentCards(
            tab: session.selectedTab,
            space: session.selectedSpace,
            at: time
        )
        startInitialNavigations(cards)
        reconcileCredentialAccess(in: session.session)
    }

    /// An unlocked empty Space or start page is an ordinary departure. Keep
    /// the same PiP lifecycle as switching between loaded tabs; security
    /// teardown uses deactivatePagePresentation instead.
    func leavePagePresentation() {
        activate(nil, presenting: [])
    }

    /// Removes every rendered page from presentation without evicting their
    /// isolated WebKit runtimes. Re-selecting the tab restores the resident
    /// page, while protected content cannot remain visible behind a lock gate.
    ///
    /// All of it goes at once, not just the focused card: a Space locking with
    /// a split open has to take every card away, and half a split left on
    /// screen would be the privacy failure the gate exists to prevent.
    func deactivatePagePresentation() {
        for runtime in tabRuntimes.values where runtime.presentationWindowID == windowID {
            runtime.page.pictureInPicture?.invalidate()
        }
        guard activeTabID != nil || !presentedTabIDs.isEmpty else { return }
        for tabID in presentedTabIDs where tabRuntimes[tabID]?.presentationWindowID == windowID {
            tabRuntimes[tabID]?.page.focusRestoration.invalidate()
        }
        activeTabID = nil
        presentedTabIDs = []
    }

    func reconcile(validTabIDs: Set<TabID>) {
        host.reconcile(validTabIDs: validTabIDs)
        if let activeTabID, !validTabIDs.contains(activeTabID) {
            self.activeTabID = nil
        }
        pruneCards(keeping: validTabIDs)
    }

    /// Drops cards for tabs that no longer exist. A split whose member was
    /// closed keeps presenting the rest; presentation is derived per selection,
    /// so a run that is no longer renderable collapses on the next one.
    private func pruneCards(keeping validTabIDs: Set<TabID>) {
        guard presentedTabIDs.contains(where: { !validTabIDs.contains($0) })
        else { return }
        presentedTabIDs = presentedTabIDs.filter { validTabIDs.contains($0) }
    }

    func reconcile(session: BrowserSession) {
        host.reconcile(session: session)
    }

    func reconcileCredentialAccess(in session: BrowserSession) {
        host.reconcileCredentialAccess(in: session)
    }

    /// Writes out the engine session state of every resident page this window
    /// routes. The app calls this when a scene stops being active, so state
    /// survives a quit before an inactive page is unloaded.
    func archiveResidentTabStates() {
        host.archiveResidentTabStates { [windowID, publishesPageMetadataCentrally] runtime in
            runtime.routingWindowID == windowID || !publishesPageMetadataCentrally
        }
    }

    func flushPendingTabStateWrites() async {
        await host.flushPendingTabStateWrites()
    }

    func reconcileTabIcons(in session: BrowserSession) {
        host.reconcileTabIcons(in: session)
    }

    func deleteData(for space: BrowserSpace) async throws {
        try await host.deleteData(for: space, on: browser.core, ephemeral: usesEphemeralWebsiteDataStores) {
            await releaseWindowRuntime(for: space)
            serverTrustOverrides.removeApprovals(for: space.profile.id)
        }
        permissionCenter.reset(spaceID: space.id)
    }

    func releaseWindowRuntime(for space: BrowserSpace) async {
        guard host.spacesReleasingData.insert(space.id).inserted else {
            nativeTabs.remove(in: space.id)
            return
        }
        defer { host.spacesReleasingData.remove(space.id) }
        await host.releasePages(of: space)
        downloadCenter.deleteRecords(
            profileID: space.profile.id,
            spaceID: space.id
        )
        if usesEphemeralWebsiteDataStores {
            profileDataStores.releaseEphemeralStore(for: space.profile.id)
        }
    }

    func closePrivateBrowsingSession(_ session: BrowserSession) {
        guard browsingMode.isPrivate else { return }
        host.closePrivateBrowsingSession()
        for space in session.spaces {
            downloadCenter.deleteRecords(
                profileID: space.profile.id,
                spaceID: space.id
            )
            permissionCenter.reset(spaceID: space.id)
            Task {
                await BrowserFaviconFallbackLoader.shared.removeAll(
                    for: space.profile.id
                )
            }
        }
        profileDataStores.releaseAllEphemeralStores()
    }

    /// Asks the core to load what the person typed or chose in the page the
    /// window shows. False when there is none or a rule refused it.
    @discardableResult
    func navigate(to input: String) -> Bool {
        activePage?.corePage.navigate(to: input) ?? false
    }

    /// The cards a visited-link restyle applies to.
    ///
    /// Every presented member, not only the focused one: a link followed in one
    /// card is followed for the window, and leaving its neighbour showing the same
    /// link unstyled until that neighbour navigates for its own reasons is a lie
    /// about what has been read. The focused tab is included even in the frame
    /// where popup adoption has activated a tab the presented list has not caught
    /// up with, and pages belonging to another Space or profile are excluded — the
    /// history being applied is this Space's.
    func visitedLinkStylingTabIDs(in space: BrowserSpace) -> [TabID] {
        _ = residencyRevision
        var seen: Set<TabID> = []
        return (presentedTabIDs + [activeTabID].compactMap { $0 }).filter { tabID in
            guard seen.insert(tabID).inserted, let page = tabRuntimes[tabID]?.page else {
                return false
            }
            return page.spaceID == space.id && page.profileID == space.profile.id
        }
    }

    func styleVisitedLinks(in space: BrowserSpace) async {
        for tabID in visitedLinkStylingTabIDs(in: space) {
            await tabRuntimes[tabID]?.page.styleVisitedLinks(history: space.history)
        }
    }

    /// A visit the core recorded restyles every card this window shows in its
    /// Space: the card beside the one that navigated is the one most likely to
    /// show the link just followed.
    private func restyleVisitedLinks(after records: Engines.PageRecords) {
        let workspace = browser.window.workspaceID
        let spaceIDs = Set(records.navigations.filter { $0.workspaceID == workspace }.map(\.spaceID))
        for spaceID in spaceIDs {
            guard let space = browser.session.space(id: spaceID) else { continue }
            Task { @MainActor [weak self] in await self?.styleVisitedLinks(in: space) }
        }
    }

    func makePeekPageLease(
        request: BrowserPeekRequest,
        in space: BrowserSpace,
        onDownloadOnlyNavigation: @escaping () -> Void
    ) -> BrowserTransientPageLease? {
        guard request.assignment == BrowserSpaceRuntimeAssignment(space: space) else { return nil }
        return host.peekPageLease(for: request) {
            makeTransientPageLease(
                url: request.url, in: space, presentation: .peek,
                engineNavigation: request.engineNavigation,
                onDownloadOnlyNavigation: onDownloadOnlyNavigation)
        }
    }

    func retainPeekPages(for requests: [BrowserPeekRequest]) {
        host.retainPeekPages(for: requests)
    }

    func makeTransientPageLease(
        url: URL,
        in space: BrowserSpace,
        presentation: TransientPresentation = .quickWindow,
        engineNavigation: BrowserEngineNavigation? = nil,
        onUserActivity: @escaping () -> Void = {},
        onDownloadOnlyNavigation: (() -> Void)? = nil
    ) -> BrowserTransientPageLease? {
        host.makeTransientPageLease(
            url: url, in: space, presentation: presentation, engineNavigation: engineNavigation,
            balancedContentRuleLists: contentBlocking.balancedRuleLists ?? [], onUserActivity: onUserActivity,
            onDownloadOnlyNavigation: onDownloadOnlyNavigation
        ) { [weak self] in
            self?.makePage(space: space, presentation: presentation)
        }
    }

    @discardableResult
    func adoptTransientPage(
        _ lease: BrowserTransientPageLease,
        as tabID: TabID,
        in space: BrowserSpace
    ) -> Bool {
        // Move the renderer before Quick Window dismissal destroys its old
        // host. SwiftUI attaches the retained native view on a later update.
        // An engine that cannot move a live page between windows leaves the
        // caller to load the tab afresh instead, and so does the core when
        // the tab may not take the page.
        guard
            let page = host.adoptTransientPage(
                lease, as: tabID, in: space, through: browser,
                prepare: { [windowID] page in
                    page.pageEngine.registration.supports(.workspaceTransfer) && page.enginePage.move(to: windowID)
                })
        else { return false }
        retainResidentPage(page, for: tabID)
        residencyRevision &+= 1
        activate(tabID)
        if let tab = space.tabs.first(where: { $0.id == tabID }) {
            page.updateNavigationContext(tab: tab)
        }
        return true
    }

    func navigatePopupInCurrentPage(
        _ request: URLRequest,
        opener: BrowserPage
    ) -> Bool {
        guard request.url != nil,
            !browser.deletingSpaceIDs.contains(opener.spaceID),
            host.leases(opener)
        else { return false }
        opener.loadWebContentRequest(request)
        return true
    }

    /// The Space a download belongs to when the engine names its source page.
    func engineDownloadAssignment(pageID: String, profileID: UUID) -> BrowserSpaceRuntimeAssignment? {
        guard let page = host.livePages.first(where: { $0.corePage.id == UUID(uuidString: pageID) }),
            page.profileID == profileID, !browser.deletingSpaceIDs.contains(page.spaceID)
        else { return nil }
        return BrowserSpaceRuntimeAssignment(spaceID: page.spaceID, profileID: page.profileID)
    }

    /// Retains a page the engine created itself — its opener, history,
    /// JavaScript state and extension tab identity — in the shared tab runtime.
    func adoptEnginePage(_ adoption: BrowserEnginePageAdoption) -> Bool {
        let profile = adoption.profileID
        let destination: SpaceID
        if let sourceID = adoption.sourcePageID {
            guard
                let opener = tabRuntimes.values.compactMap(\.page)
                    .first(where: { $0.corePage.id == UUID(uuidString: sourceID) }),
                opener.profileID == profile
            else { return false }
            destination = opener.spaceID
        } else {
            guard adoption.windowID == windowID else { return false }
            // A window Crest opened for an engine-created window names the
            // Space it was opened for: it has no page yet to treat as opener.
            if let target = adoption.spaceID {
                destination = target
            } else if let opener = activePage, opener.profileID == profile {
                destination = opener.spaceID
            } else {
                return false
            }
        }
        guard !browser.deletingSpaceIDs.contains(destination),
            let registration = popupTabHost.openTab(adoption.url, destination, adoption.foreground),
            registration.space.profile.id == profile
        else { return false }
        guard let page = makePage(space: registration.space, tabID: registration.tab.id) else {
            popupTabHost.closeTab(registration.tab.id, registration.space.id)
            return false
        }
        page.markOpenedAsPopup()
        page.updateNavigationContext(tab: registration.tab)
        guard page.engineAdapter.adoptEngineCreatedPage(adoption.token) else {
            page.release(keepingState: false)
            popupTabHost.closeTab(registration.tab.id, registration.space.id)
            return false
        }
        retainResidentPage(page, for: registration.tab.id)
        residencyRevision &+= 1
        if adoption.foreground { activate(registration.tab.id) }
        return true
    }

    /// Adopts a page the opener's engine created for a popup as a new tab in
    /// the opener's Space, selected unless `selecting` is false. WebKit builds
    /// the popup's page from what `webKit` gives it for the tab's Space.
    ///
    /// Declines — leaving the coordinator to route the destination into an
    /// ordinary tab — when the opener is not a resident page of this pool.
    /// Transient openers have already had the opportunity to keep the request in
    /// their lease before this adoption path is reached.
    func adoptPopupPage(
        requestedURL: URL?,
        opener: BrowserPage,
        selecting: Bool,
        webKit: (BrowserSpace) -> WebKitPageInputs
    ) -> BrowserPage? {
        guard tabID(for: opener) != nil,
            !browser.deletingSpaceIDs.contains(opener.spaceID),
            let registration = popupTabHost.openTab(requestedURL, opener.spaceID, selecting),
            registration.space.id == opener.spaceID,
            registration.space.profile.id == opener.profileID
        else { return nil }

        guard
            let page = makePage(
                space: registration.space,
                tabID: registration.tab.id,
                webKit: webKit(registration.space)
            )
        else {
            popupTabHost.closeTab(registration.tab.id, registration.space.id)
            return nil
        }
        page.markOpenedAsPopup()
        page.updateNavigationContext(tab: registration.tab)
        retainResidentPage(page, for: registration.tab.id)
        residencyRevision &+= 1
        if selecting { activate(registration.tab.id) }
        return page
    }

    /// Honors `window.close()` by closing the popup's tab through the same store
    /// path the tab list's close control uses. The page itself is released after
    /// the WebKit callback unwinds, because tearing a web view down inside its
    /// own delegate callback is not safe.
    func closeWebContentInitiatedPage(_ page: BrowserPage) {
        guard page.wasOpenedAsPopup, let tabID = tabID(for: page) else { return }
        popupTabHost.closeTab(tabID, page.spaceID)
        Task { @MainActor [weak self] in
            self?.unloadPage(for: tabID)
        }
    }

    func discardDownloadOnlyPage(_ page: BrowserPage) {
        guard !host.discardDownloadOnlyTransientPage(page) else { return }
        closeWebContentInitiatedPage(page)
    }

    func restorePictureInPictureSourcePage(_ page: BrowserPage) {
        guard page.pictureInPicture?.canRestoreSource == true,
            let tabID = tabID(for: page),
            tabRuntimes[tabID]?.routingWindowID == windowID,
            !browser.deletingSpaceIDs.contains(page.spaceID),
            let window = presentationWindow,
            let session = selectPictureInPictureSource(
                BrowserTabRuntimeAssignment(tabID: tabID, spaceID: page.spaceID, profileID: page.profileID))
        else { return }
        // Claim the existing runtime and its split group through normal
        // selection. WebKit finishes returning the original video inline once
        // SwiftUI reattaches its view; never recreate or navigate the page here.
        setWindowFocused(true)
        select(session: session)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func activateNotificationSourcePage(_ page: BrowserPage) {
        guard let tabID = tabID(for: page) else { return }
        activateHostedNotificationSource(page.spaceID, tabID)
    }

    /// Every page resident in this pool's tabs.
    var residentPages: [BrowserPage] { host.residentPages }

    func goBack() { activePage?.goBack() }
    func goForward() { activePage?.goForward() }
    func goBack(to item: BrowserNavigationHistoryItem) { activePage?.goBack(toDepth: item.depth) }
    func goForward(to item: BrowserNavigationHistoryItem) { activePage?.goForward(toDepth: item.depth) }

    /// Explicit durable close differs from residency eviction only when the
    /// person chose to return to the saved URL on the next open.
    func closeDurablePage(_ assignment: BrowserTabRuntimeAssignment, discardState: Bool) -> Bool {
        host.closeDurablePage(assignment, discardState: discardState)
    }

    func discardArchivedTabState(matching assignment: BrowserTabRuntimeAssignment) {
        host.discardArchivedTabState(matching: assignment)
    }

    func unloadPage(for tabID: TabID) {
        host.unloadPage(for: tabID)
    }

    @discardableResult
    func unloadPage(
        for tabID: TabID,
        matching assignment: BrowserSpaceRuntimeAssignment
    ) -> Bool {
        host.unloadPage(for: tabID, matching: assignment)
    }

    /// Releases a Space's resident pages without archiving them. Normal Space
    /// switching and locking preserve residency and do not call this teardown.
    func unloadPages(in spaceID: SpaceID) {
        host.unloadPages(in: spaceID)
    }

    /// Hides a protected Space without unloading its tabs. Unlocking can reuse
    /// the same WebKit pages, including scroll position and unsaved form state.
    /// Resident pages remain subject to normal idle and memory-pressure limits.
    ///
    /// Previously archived state is still purged from disk. This preserves only
    /// live pages, not a disk snapshot of a protected Space. The access views
    /// gate ordinary and transient content until authentication succeeds.
    func relockProtectedSpace(_ space: BrowserSpace) {
        guard space.accessPolicy.requiresAuthentication else { return }
        // A background Space can still remember its editor after departure.
        // Locking ends that focus session even though its pages stay resident.
        for page in host.livePages where page.spaceID == space.id {
            page.focusRestoration.invalidate()
            page.pictureInPicture?.invalidate()
        }
        if activePage?.spaceID == space.id
            || presentedTabIDs.contains(where: { tabRuntimes[$0]?.page.spaceID == space.id })
        {
            deactivatePagePresentation()
        }
        host.tabState.removeStates(profileID: space.profile.id)
    }

    func reloadOrStop(in session: BrowserPresentedSession) {
        reload(.standard, selectedBy: session)
    }

    func forceReload(in session: BrowserPresentedSession) {
        guard let tab = session.selectedTab,
            let space = session.selectedSpace
        else { return }
        let residentPage = tabRuntimes[tab.id]?.page
        let canReloadResidentPage =
            residentPage?.spaceID == space.id
            && residentPage?.profileID == space.profile.id
            && residentPage?.live.documentURL != nil
        select(session: session)
        guard canReloadResidentPage else { return }
        activePage?.reload()
    }

    func stopLoading() {
        activePage?.stopLoading()
    }

    func reloadFromOrigin(in session: BrowserPresentedSession) {
        reload(.fromOrigin, selectedBy: session)
    }

    func clearSiteDataAndReload() async {
        await activePage?.clearSiteDataAndReload()
    }

    func presentFind() {
        activePage?.presentFind()
    }

    func showWebInspector() {
        activePage?.showWebInspector()
    }

    func toggleReaderMode() {
        activePage?.toggleReaderMode()
    }

    @discardableResult
    func zoomIn() -> Bool {
        activePage?.zoomIn() == true
    }

    @discardableResult
    func zoomOut() -> Bool {
        activePage?.zoomOut() == true
    }

    @discardableResult
    func resetZoom() -> Bool {
        activePage?.resetZoom() == true
    }

    func defaultPageZoomDidChange(to zoom: CGFloat) {
        host.defaultPageZoomDidChange(to: zoom)
    }

    @discardableResult
    func copyPageLink() -> Bool {
        activePage?.copyPageLink() == true
    }

    @discardableResult
    func copyPageLinkAsMarkdown() -> Bool {
        activePage?.copyPageLinkAsMarkdown() == true
    }

    func pullFavicon(
        for tabID: TabID
    ) async -> (data: Data, iconAccent: BrowserTabIconAccent?)? {
        await host.pullFavicon(for: tabID)
    }

    func pullFavicon(
        for tabID: TabID,
        matching assignment: BrowserSpaceRuntimeAssignment
    ) async -> (data: Data, iconAccent: BrowserTabIconAccent?)? {
        await host.pullFavicon(for: tabID, matching: assignment)
    }

    func sharePage() {
        activePage?.sharePage()
    }

    func printPage() {
        activePage?.printPage()
    }

    func exportPDF() {
        activePage?.exportPDF()
    }

    func exportWebArchive() {
        activePage?.exportWebArchive()
    }

    /// Releases what memory pressure takes back that the core does not
    /// decide; see `BrowserPageHost.relieveMemoryPressure`.
    func relieveMemoryPressure(_ level: MemoryPressureLevel) {
        host.relieveMemoryPressure(level, presenting: Array(runtimeStore.presentedTabIDs))
    }

    /// The tab's resident page, or a new one the core opened for it; nil when
    /// the core refuses the tab a page.
    private func page(for tab: BrowserTab, space: BrowserSpace) -> BrowserPage? {
        if let existingPage = tabRuntimes[tab.id]?.page {
            if existingPage.spaceID == space.id,
                existingPage.profileID == space.profile.id
            {
                let page = existingPage
                page.setCredentialAccessEnabled(
                    space.credentialPreferences.isEnabled
                )
                page.updateNavigationContext(tab: tab)
                return page
            }
            // The tab moved to another Space, so the state archived under its old
            // profile describes a runtime it no longer belongs to.
            host.tabState.removeState(
                profileID: existingPage.profileID,
                tabID: tab.id
            )
            tabRuntimes.removeValue(forKey: tab.id)?.release(keepingState: false)
        }
        guard let page = makePage(space: space, tabID: tab.id) else { return nil }
        page.updateNavigationContext(tab: tab)
        retainResidentPage(page, for: tab.id)
        residencyRevision &+= 1
        return page
    }

    /// Opens a page through the core for `tabID` in `space`, or for a
    /// transient request presenting as `presentation` when `tabID` is nil, on
    /// the engine the core chooses, and hosts it. `webKit` builds the page when WebKit hosts it, and this
    /// pool's own WebKit configuration builds it otherwise. Nil when the core
    /// refuses the page.
    /// A page the core opens for `tabID` in `space`, or for a transient request
    /// presenting as `presentation`; WebKit builds it from `webKit`, or from
    /// the Space's own inputs. Nil when the core refuses it.
    private func makePage(
        space: BrowserSpace,
        tabID: TabID? = nil,
        presentation: TransientPresentation? = nil,
        webKit: WebKitPageInputs? = nil
    ) -> BrowserPage? {
        let interval = Self.lifecycleSignposter.beginInterval("Create Browser Page")
        defer {
            Self.lifecycleSignposter.endInterval("Create Browser Page", interval)
        }

        guard
            let opened = browser.openPage(
                in: space.id, for: tabID, presenting: presentation, webKit: webKit ?? webKitInputs(for: space))
        else { return nil }
        let engine: any BrowserPageEngineAdapter
        if let webKitPage = opened.built as? WebKitEnginePage {
            engine = BrowserWebKitPageAdapter(page: webKitPage)
        } else if let adapter = opened.built as? any BrowserPageEngineAdapter {
            engine = adapter
        } else {
            preconditionFailure("An engine built something other than a desktop page.")
        }
        let routing = BrowserPageWindowRouting(pool: self)
        let page = BrowserPage(
            corePage: opened.page,
            engine: engine,
            dialogPresenter: dialogPresenter,
            downloadCenter: downloadCenter,
            permissionCenter: permissionCenter,
            hostedNotificationCenter: hostedNotificationCenter,
            passkeyAccess: passkeyAccess,
            serverTrustOverrides: serverTrustOverrides,
            mediaSessionStore: tabID == nil ? nil : mediaSessionStore,
            spaceID: space.id,
            profileID: space.profile.id,
            spaceName: space.name,
            allowsCredentialAccess: !browsingMode.isPrivate,
            isCredentialAccessEnabled:
                space.credentialPreferences.isEnabled,
            defaultPageZoom: pageZoomPreferences.defaultZoom,
            loadHTTPAuthenticationCredential: { [weak routing] protectionSpace in
                try await routing?.pool?.loadHTTPAuthenticationCredential(protectionSpace, space.id)
            },
            saveHTTPAuthenticationCredential: { [weak routing] request in
                try await routing?.pool?.saveHTTPAuthenticationCredential(request, space.id)
            },
            openNewTab: { [weak routing] url in routing?.pool?.openNewTab(url) },
            openModifiedLink: { [weak routing] url, spaceID, selecting in
                routing?.pool?.openModifiedLink(url, in: spaceID, selecting: selecting)
            },
            openPeek: { [weak routing] in routing?.pool?.openPeek($0) },
            handleLinkDrag: { [weak routing] in routing?.pool?.handleLinkDrag($0) },
            splitLinkHost: splitLinkHost,
            linkDestinationHost: linkDestinationHost
        )
        page.setPrivateBrowsing(browsingMode.isPrivate)
        page.host = self
        page.windowRouting = routing
        return page
    }

    private func tabID(for page: BrowserPage) -> TabID? {
        host.tabID(for: page)
    }

    private func retainResidentPage(_ page: BrowserPage, for tabID: TabID) {
        if let runtime = tabRuntimes[tabID] {
            runtime.page = page
        } else {
            runtimeStore.install(BrowserTabRuntime(page: page), for: tabID, from: self)
        }
    }

    private func loadInitialURL(for tab: BrowserTab, into page: BrowserPage) {
        // WebKit owns an adopted popup's first navigation. Loading it here would
        // replace the document `window.open()` handed to the opener.
        guard !page.isAwaitingPopupNavigation else { return }
        // A page its engine shows something in, or that is already heading
        // somewhere, has had its first navigation.
        guard page.pageEngine.currentURL == nil, page.navigationReporter?.pendingURL == nil,
            page.live.pendingURL == nil, let url = tab.url
        else { return }
        let interval = Self.lifecycleSignposter.beginInterval("Start Initial Navigation")
        // The adapter restores its own navigation state instead of a plain load.
        // Missing or incompatible archives fall back to the tab's current URL.
        if let state = host.archivedInteractionState(
            for: tab,
            spaceID: page.spaceID,
            profileID: page.profileID,
            expecting: url
        ), page.restoreInteractionState(state, expecting: url) {
            Self.lifecycleSignposter.endInterval("Start Initial Navigation", interval)
            return
        }
        page.corePage.navigate(to: url.absoluteString)
        Self.lifecycleSignposter.endInterval("Start Initial Navigation", interval)
    }

    private func reload(
        _ mode: BrowserPageReloadMode,
        selectedBy session: BrowserPresentedSession
    ) {
        guard let tab = session.selectedTab,
            let space = session.selectedSpace
        else { return }
        let residentPage = tabRuntimes[tab.id]?.page
        let canReloadResidentPage =
            residentPage?.spaceID == space.id
            && residentPage?.profileID == space.profile.id
            && residentPage?.live.documentURL != nil

        select(session: session)

        guard canReloadResidentPage else {
            // Selection creates a missing WebView and starts its saved URL.
            // Do not immediately issue a second navigation for that recovery.
            return
        }
        activePage?.performReload(mode)
    }

    /// Focuses a tab that is already on screen, or brings one on screen beside
    /// the cards already there.
    ///
    /// Popup adoption and extension selection reach focus without going through
    /// `select`, one frame ahead of the store-driven reselection that settles
    /// the presented set properly. Adding the tab here rather than replacing
    /// the set is what keeps that frame from rendering a card with no page.
    private func activate(_ tabID: TabID) {
        var presented = presentedTabIDs
        if !presented.contains(tabID) {
            presented.append(tabID)
        }
        activate(tabID, presenting: presented)
    }

    /// Puts `presentedTabIDs` on screen in order with `tabID` focused.
    private func activate(_ tabID: TabID?, presenting presentedTabIDs: [TabID]) {
        prepareFocusTransition(to: tabID.flatMap { tabRuntimes[$0]?.page })
        requestAutomaticPictureInPicture(forDeparturesBefore: presentedTabIDs)
        for arrivingTabID in presentedTabIDs where !self.presentedTabIDs.contains(arrivingTabID) {
            tabRuntimes[arrivingTabID]?.page.pictureInPicture?.returnToTab()
        }
        activeTabID = tabID
        self.presentedTabIDs = presentedTabIDs
    }

    private func requestAutomaticPictureInPicture(forDeparturesBefore arriving: [TabID]) {
        let departed = Set(presentedTabIDs).subtracting(arriving)
        // Only pages leaving the visible set qualify. Moving focus within a
        // split must not float a video that is still visible beside the tab.
        let departures = ([activeTabID].compactMap { $0 } + presentedTabIDs)
            .filter { departed.contains($0) }
        var requested: Set<TabID> = []
        for tabID in departures
        where requested.insert(tabID).inserted
            && !runtimeStore.isPresented(tabID, outside: windowID)
        {
            tabRuntimes[tabID]?.page.pictureInPicture?.leaveTab()
        }
    }

    private func prepareFocusTransition(to destination: BrowserPage?) {
        let source = activePage
        guard source !== destination else { return }
        if let destination, !isWindowFocused,
            let runtime = tabRuntimes.values.first(where: { $0.page === destination }),
            let owner = runtime.presentationWindowID, owner != windowID
        {
            return
        }
        guard
            activeTabID.flatMap({ tabRuntimes[$0]?.presentationWindowID }) == windowID
                || source == nil
        else { return }
        guard let source, let destination else {
            source?.focusRestoration.invalidate()
            destination?.focusRestoration.invalidate()
            return
        }

        // Each resident page owns its own responder. Switching Spaces does
        // not change that ownership; moving a tab or replacing its profile
        // recreates the page and invalidates the old responder separately.
        source.focusRestoration.captureBeforeDeparture()
        destination.focusRestoration.requestRestoration(
            displacing: source.nativeView
        )
    }

    func pruneTransientLeases() {
        host.pruneTransientLeases()
    }

}

extension BrowserPagePool: BrowserTabCopying {
    func sourceForTabCopy(_ source: BrowserTab, in space: BrowserSpace) -> BrowserTab {
        host.sourceForTabCopy(source, in: space)
    }

    func prepareTabCopy(from source: BrowserTab, to copy: inout BrowserTab, in space: BrowserSpace) {
        host.prepareTabCopy(from: source, to: &copy, in: space)
    }
}

extension BrowserPagePool: BrowserTabLinkProviding {
    func liveLinkURL(for assignment: BrowserTabRuntimeAssignment) -> URL? {
        host.liveLinkURL(for: assignment)
    }
}
