import Dispatch
import Observation
import UIKit
import UniformTypeIdentifiers
import WebKit

@Observable
@MainActor
final class MobileBrowserPageStore:
    BrowserSpaceDataDeleting,
    MobileBrowserPageHosting,
    BrowserDefaultPageZoomObserving
{
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

    /// The focused card: the one page the toolbar, find bar, navigation
    /// controls, and every lifecycle observer speak for. Split View adds cards
    /// beside it without adding a second focus.
    private(set) var activePage: MobileBrowserPage? {
        willSet { if activePage !== newValue { activePage?.translation.suspend() } }
    }

    /// Every card the content area is presenting, in column order.
    ///
    /// Derived from the cards the core shows in this scene, the same source the
    /// content area lays out, so the two can never disagree about who is on
    /// screen. A tab outside a shown split presents alone, which is one element
    /// rather than a special case, and the active page is always a member while
    /// anything is presented.
    ///
    /// Deliberately observable: a carousel cell and an iPad column both read it
    /// through `residentPage(matching:)` and have to re-render when membership
    /// changes.
    private(set) var presentedTabIDs: [TabID] = []
    /// The pages this window hosts: its tabs', its leases' and the state its
    /// tabs leave when their pages go.
    let host: BrowserPageHost
    var nativeTabs: BrowserNativeTabStore { host.nativeTabs }
    var residencyRevision: Int { host.revision }
    private(set) var urlCopyFeedbackRevision = 0
    private(set) var pageZoomFeedbackLabel = "100%"
    private(set) var pageZoomFeedbackRevision = 0
    var contentBlockingErrorDescription: String? { contentBlocking.errorDescription }
    let downloadCenter: BrowserDownloadCenter
    let downloadRiskConfirmation: MobileDownloadRiskConfirmationCoordinator
    /// The answers to the core's questions about this mode's downloads, which
    /// a store made on its own keeps while it lives.
    @ObservationIgnored private let downloadPrompts: BrowserDownloadPrompts
    let permissionCenter: BrowserSitePermissionCenter
    let serverTrustOverrides = BrowserServerTrustOverrideStore()

    @ObservationIgnored private var ephemeralDataStores: [UUID: WKWebsiteDataStore] = [:]
    @ObservationIgnored private let popupTabHost: BrowserPopupTabHost
    @ObservationIgnored private let mediaSessionStore: BrowserMediaSessionStore?
    @ObservationIgnored let linkDestinationHost: BrowserLinkDestinationHost
    @ObservationIgnored private let openNewTab: (URL) -> Void
    @ObservationIgnored private let openModifiedLink: ModifiedLinkOpener
    @ObservationIgnored private let openPeek: (BrowserPeekRequest) -> Void
    /// Tells the core of the latest squeeze, once the pages' media is fresh.
    @ObservationIgnored private var memoryPressureReport: Task<Void, Never>?
    @ObservationIgnored private let browsingMode: BrowserBrowsingMode
    @ObservationIgnored private let usesEphemeralWebsiteDataStores: Bool
    @ObservationIgnored private let pageZoomPreferences: BrowserDefaultPageZoomStore
    @ObservationIgnored private let loadHTTPAuthenticationCredential: HTTPAuthenticationCredentialLoader
    @ObservationIgnored private let saveHTTPAuthenticationCredential: HTTPAuthenticationCredentialSaver
    @ObservationIgnored private let contentBlocking: BrowserContentBlockingController
    @ObservationIgnored private var memoryPressureSource: (any DispatchSourceMemoryPressure)?
    @ObservationIgnored private var memoryPressureCoalescer = BrowserMemoryPressureCoalescer()
    /// The window this store hosts pages for. Its pages open through the core
    /// from this window, in its workspace.
    @ObservationIgnored let browser: BrowserStore

    init(
        browser: BrowserStore,
        monitorsMemoryPressure: Bool = false,
        browsingMode: BrowserBrowsingMode = .standard,
        usesEphemeralWebsiteDataStores: Bool =
            BrowserLaunchEnvironment.current.requiresIsolation,
        pageZoomPreferences: BrowserDefaultPageZoomStore = .shared,
        permissionCenter: BrowserSitePermissionCenter = BrowserSitePermissionCenter(),
        mediaSessionStore: BrowserMediaSessionStore? = nil,
        downloads: MobileBrowserDownloads? = nil,
        loadHTTPAuthenticationCredential:
            @escaping HTTPAuthenticationCredentialLoader = { _, _ in nil },
        saveHTTPAuthenticationCredential:
            @escaping HTTPAuthenticationCredentialSaver = { _, _ in },
        contentRuleListProvider: (any BrowserContentRuleListProviding)? = nil,
        tabStateArchive: (any BrowserTabStateArchiving)? = nil,
        popupTabHost: BrowserPopupTabHost = .unavailable,
        linkDestinationHost: BrowserLinkDestinationHost = .unavailable,
        openNewTab: @escaping (URL) -> Void = { _ in },
        openModifiedLink: @escaping ModifiedLinkOpener = { _, _, _ in nil },
        openPeek: @escaping (BrowserPeekRequest) -> Void = { _ in }
    ) {
        self.browser = browser
        self.browsingMode = browsingMode
        self.usesEphemeralWebsiteDataStores =
            usesEphemeralWebsiteDataStores || browsingMode.isPrivate
        self.pageZoomPreferences = pageZoomPreferences
        // A private store's tabs leave no state on disk, even if an archive is
        // handed in.
        host = BrowserPageHost(archive: self.usesEphemeralWebsiteDataStores ? nil : tabStateArchive)
        self.popupTabHost = popupTabHost
        self.mediaSessionStore = browsingMode.isPrivate ? nil : mediaSessionStore
        self.permissionCenter = permissionCenter
        self.loadHTTPAuthenticationCredential = loadHTTPAuthenticationCredential
        self.saveHTTPAuthenticationCredential = saveHTTPAuthenticationCredential
        self.linkDestinationHost = linkDestinationHost
        self.openNewTab = openNewTab
        self.openModifiedLink = openModifiedLink
        self.openPeek = openPeek
        // Windows share their browsing mode's downloads; a store made on its
        // own, such as a preview's, keeps them over its window's core.
        let downloads =
            downloads
            ?? MobileBrowserDownloads(
                core: browser.core,
                browsingMode: browsingMode,
                permissionCenter: permissionCenter
            )
        downloadRiskConfirmation = downloads.riskConfirmation
        downloadCenter = downloads.center
        downloadPrompts = downloads.prompts
        contentBlocking = BrowserContentBlockingController(
            provider: contentRuleListProvider ?? BrowserContentRuleListProvider.forLaunch(core: downloads.center.core))
        if monitorsMemoryPressure {
            installMemoryPressureSource()
        }
        pageZoomPreferences.register(self)
        host.dropPresentation = { [weak self] in self?.dropPresentation(of: $0) }
        browser.core.engines.observeRecords(self) { [weak self] in self?.restyleVisitedLinks(after: $0) }
        browser.core.followUnloadedPages(self) { [weak self] in self?.host.pageUnloaded($0) }
    }

    deinit {
        memoryPressureReport?.cancel()
        memoryPressureSource?.cancel()
    }

    var canGoBack: Bool { activePage?.live.canGoBack == true }
    var canGoForward: Bool { activePage?.live.canGoForward == true }
    var backHistory: [BrowserNavigationHistoryItem] { activePage?.backHistory ?? [] }
    var forwardHistory: [BrowserNavigationHistoryItem] { activePage?.forwardHistory ?? [] }
    var activeURL: URL? { activePage?.live.displayURL }
    var pageZoomLabel: String {
        BrowserPageZoomPolicy.percentageLabel(for: activePage?.pageZoom ?? 1)
    }
    var readerModeState: BrowserReaderModeState {
        activePage?.readerModeState ?? .unavailable
    }
    var readerModeActionTitle: LocalizedStringResource {
        readerModeState.isActive ? "Hide Reader" : "Show Reader"
    }
    var preferredContentModeActionTitle: LocalizedStringResource {
        activePage?.isRequestingDesktopSite == true
            ? "Request Mobile Website"
            : "Request Desktop Website"
    }
    var residentPageCount: Int { host.runtimes.count }

    var retainedTransientPageCount: Int { host.retainedTransientPageCount }

    func prepareContentBlocking() async {
        await contentBlocking.prepare()
    }

    /// Gives every page its Space's content blocking in the scene's
    /// workspace, reloading presented pages only when their Space's
    /// protection level changes.
    func reconcileContentBlocking() async {
        let update = await contentBlocking.reconcile(in: browser.workspaceModel)
        for (tabID, runtime) in host.runtimes {
            let page = runtime.page
            let isPresentedPage = presentedTabIDs.contains(tabID)
            page.applyContentBlocking(
                policy: update.policy(for: page.spaceID),
                balancedRuleLists: contentBlocking.balancedRuleLists ?? [],
                activation: update.activation(for: page.spaceID, isPresented: isPresentedPage)
            )
        }
        for lease in host.liveTransientLeases {
            lease.applyContentBlocking(
                policy: update.policy(for: lease.spaceID),
                balancedRuleLists: contentBlocking.balancedRuleLists ?? []
            )
        }
    }

    /// Refreshes rule lists without reloading unchanged documents.
    func reloadContentBlocking() async {
        contentBlocking.invalidateRuleLists()
        await reconcileContentBlocking()
    }

    /// What the store's runtime state follows in the scene's workspace: tab
    /// icons, content blocking and credential access, compared between
    /// changes so each is reconciled only when it moved.
    var runtimeProjection: BrowserRuntimeSessionProjection {
        BrowserRuntimeSessionProjection(workspace: browser.workspaceModel, images: browser.core.state.favicons)
    }

    /// Which tab of the workspace belongs to which Space and profile, which
    /// page residency follows.
    var tabRuntimeAssignments: Set<BrowserTabRuntimeAssignment> {
        Set(
            browser.spaceModels.flatMap { space in
                space.tabs.models.map {
                    BrowserTabRuntimeAssignment(tabID: $0.id, spaceID: space.id, profileID: space.profileID)
                }
            })
    }

    /// Presents what the scene shows.
    func select(at time: Date = .now) {
        if !prepareSelectedPage(at: time) {
            deactivatePagePresentation()
        }
        reconcileCredentialAccess()
    }

    /// Presents what the scene shows and asks the core to load what the
    /// person typed or chose in its page, instead of the tab's own address.
    /// False when there is no page or a rule refused the load.
    @discardableResult
    func selectAndNavigate(to input: String, at time: Date = .now) -> Bool {
        defer { reconcileCredentialAccess() }
        guard prepareSelectedPage(at: time, loadsInitialURL: false) else {
            deactivatePagePresentation()
            return false
        }
        return activePage?.corePage.navigate(to: input) ?? false
    }

    func loadOpenedLink(_ registration: BrowserModifiedLinkRegistration, request: URLRequest, selecting: Bool) {
        let space = registration.space
        guard registration.tab.nativeContent == nil,
            let page = makeResidentPage(
                for: BrowserPageTab(registration.tab, images: browser.core.state.favicons), in: space,
                loadsInitialURL: false)
        else { return }
        host.retain(page, for: registration.tab.id)
        page.load(request)
        if selecting { select() }
    }

    private func prepareSelectedPage(at time: Date, loadsInitialURL: Bool = true) -> Bool {
        guard let space = browser.shownSpace,
            let tab = browser.shownTab
        else {
            return false
        }
        // Unlike macOS, only the focused member is built here. The carousel
        // materializes its cells lazily and each one calls
        // `prepareResidentPage(for:in:)` as it approaches, which is what keeps a
        // four-member group to focused ±1 live web views on a phone.
        let presented = presentedMemberIDs(for: tab, in: space)
        if tab.nativeContent != nil {
            nativeTabs.load(tab: tab, space: space, at: time)
            deactivatePagePresentation()
            presentedTabIDs = presented
            return true
        }
        let pageTab = BrowserPageTab(tab, images: browser.core.state.favicons)
        if let existing = host.page(
            matching: BrowserTabRuntimeAssignment(tabID: tab.id, spaceID: space.id, profileID: space.profileID))
        {
            existing.setCredentialAccessEnabled(space.settings.credentialPreferences.isEnabled)
            existing.updateNavigationContext(tab: pageTab)
            activate(existing, presenting: presented)
            return true
        }
        releaseMismatchedPage(of: tab.id)

        // The core refuses a page in a locked Space or one being deleted.
        guard let page = makeResidentPage(for: pageTab, in: space, loadsInitialURL: loadsInitialURL) else {
            return false
        }
        host.retain(page, for: tab.id)
        activate(page, presenting: presented)
        return true
    }

    /// Lets go of the page a tab kept in another Space: the state archived
    /// under its old profile describes a runtime it no longer belongs to.
    private func releaseMismatchedPage(of tabID: TabID) {
        guard let mismatched = host.runtimes.removeValue(forKey: tabID) else { return }
        host.tabState.removeState(profileID: mismatched.page.profileID, tabID: tabID)
        mismatched.release(keepingState: false)
        host.revision &+= 1
    }

    /// The cards `tab` brings on screen: the ones the core shows beside it in
    /// this scene, or the tab alone when the scene shows it in none.
    private func presentedMemberIDs(for tab: TabStateModel, in space: SpaceModel) -> [TabID] {
        let members = browser.cards(in: space).map(\.id)
        return members.contains(tab.id) ? members : [tab.id]
    }

    /// Builds a resident page for a presented card that is not the focused one.
    ///
    /// Same guards as the selected-page path minus the activation: the card is
    /// on screen, so its page must start loading immediately, but focus stays
    /// where the session put it. Answers the page a card can bind, or `nil` when
    /// the tab is not a live member of the selected Space right now.
    @discardableResult
    func prepareResidentPage(for tabID: TabID, at time: Date = .now) -> MobileBrowserPage? {
        guard let space = browser.shownSpace,
            let tab = space.tabs.model(tabID)
        else { return nil }

        if tab.nativeContent != nil {
            nativeTabs.load(tab: tab, space: space, at: time)
            return nil
        }
        let pageTab = BrowserPageTab(tab, images: browser.core.state.favicons)
        if let existing = host.page(
            matching: BrowserTabRuntimeAssignment(tabID: tabID, spaceID: space.id, profileID: space.profileID))
        {
            existing.setCredentialAccessEnabled(space.settings.credentialPreferences.isEnabled)
            existing.updateNavigationContext(tab: pageTab)
            return existing
        }
        releaseMismatchedPage(of: tabID)

        guard let page = makeResidentPage(for: pageTab, in: space) else { return nil }
        host.retain(page, for: tabID)
        return page
    }

    /// The resident page of a presented card, once its Space and profile are
    /// confirmed to be the ones the caller is drawing.
    ///
    /// A card binds a page it did not select, so the drift the selected-page port
    /// guards against is a live risk here too: a Space switch or a profile
    /// rebuild can leave a cell holding a stale assignment for one frame, and
    /// binding a page across that boundary is exactly the isolation failure
    /// per-Space browsing exists to prevent.
    ///
    /// Membership is checked rather than residency alone: a background tab can
    /// keep a resident page for as long as memory allows, and handing one to a
    /// card would put a second host on a web view that already has one.
    func residentPage(
        matching assignment: BrowserTabRuntimeAssignment
    ) -> MobileBrowserPage? {
        _ = residencyRevision
        guard presentedTabIDs.contains(assignment.tabID) else { return nil }
        return host.page(matching: assignment)
    }

    /// Removes every rendered page from presentation without evicting their
    /// isolated WebKit runtimes. Selecting that tab again can reuse the resident
    /// page, but no previous Space can remain visible underneath the tab viewer
    /// or a private-Space lock transition.
    ///
    /// All of it goes at once, not just the focused card: a Space locking with a
    /// split open has to take every card away, and half a split left on screen
    /// would be the privacy failure the gate exists to prevent.
    func deactivatePagePresentation() {
        guard activePage != nil || !presentedTabIDs.isEmpty else { return }
        presentedTabIDs = []
        self.activePage = nil
    }

    /// Takes a tab's card off screen once its page or native content went.
    private func dropPresentation(of tabID: TabID) {
        if activePage?.tabID == tabID { activePage = nil }
        if presentedTabIDs.contains(tabID) { presentedTabIDs.removeAll { $0 == tabID } }
    }

    func reconcile(validTabIDs: Set<TabID>) {
        host.reconcile(validTabIDs: validTabIDs)
        if let activePage, !validTabIDs.contains(activePage.tabID) {
            self.activePage = nil
        }
        // A card whose tab is gone must stop being a card in the same pass, or
        // the carousel would keep a cell for a member the session no longer has.
        if presentedTabIDs.contains(where: { !validTabIDs.contains($0) }) {
            presentedTabIDs = presentedTabIDs.filter { validTabIDs.contains($0) }
        }
    }

    /// Releases the pages of tabs the scene's workspace no longer holds and
    /// keeps the rest current.
    func reconcile() {
        host.reconcile(workspace: browser.workspaceModel, images: browser.core.state.favicons)
    }

    /// Gives every page its Space's password preference.
    func reconcileCredentialAccess() {
        host.reconcileCredentialAccess(in: browser.workspaceModel)
    }

    /// Gives each resident page its tab's current context, such as its icon.
    func reconcileTabIcons() {
        host.reconcileTabIcons(in: browser.workspaceModel, images: browser.core.state.favicons)
    }

    func deleteData(for space: BrowserSpaceRuntimeAssignment) async throws {
        try await host.deleteData(for: space, on: browser.core, ephemeral: usesEphemeralWebsiteDataStores) {
            await releaseWindowRuntime(for: space)
            serverTrustOverrides.removeApprovals(for: space.profileID)
        }
        permissionCenter.reset(spaceID: space.spaceID)
    }

    func releaseWindowRuntime(for space: BrowserSpaceRuntimeAssignment) async {
        guard host.spacesReleasingData.insert(space.spaceID).inserted else {
            nativeTabs.remove(in: space.spaceID)
            return
        }
        defer { host.spacesReleasingData.remove(space.spaceID) }
        await host.releasePages(of: space)
        downloadCenter.deleteRecords(profileID: space.profileID, spaceID: space.spaceID)
        if usesEphemeralWebsiteDataStores {
            ephemeralDataStores.removeValue(forKey: space.profileID)
        }
    }

    /// Lets go of everything the private workspace kept, in each of the
    /// Spaces `spaces` names, as its scene closes.
    func closePrivateBrowsingSession(_ spaces: [BrowserSpaceRuntimeAssignment]) {
        guard browsingMode.isPrivate else { return }
        host.closePrivateBrowsingSession()
        memoryPressureReport?.cancel()
        memoryPressureReport = nil
        activePage = nil
        presentedTabIDs = []
        for space in spaces {
            downloadCenter.deleteRecords(profileID: space.profileID, spaceID: space.spaceID)
            permissionCenter.reset(spaceID: space.spaceID)
            Task {
                await BrowserFaviconFallbackLoader.shared.removeAll(for: space.profileID)
            }
        }
        ephemeralDataStores.removeAll()
    }

    func styleVisitedLinks(in space: SpaceModel) async {
        await activePage?.styleVisitedLinks(history: space.history.entries)
    }

    /// A visit the core recorded in the Space the active page shows restyles
    /// its visited links.
    private func restyleVisitedLinks(after records: Engines.PageRecords) {
        guard let page = activePage,
            records.navigations.contains(where: {
                $0.workspaceID == browser.window.workspaceID && $0.spaceID == page.spaceID
            }),
            let space = browser.spaceModel(page.spaceID)
        else { return }
        Task { @MainActor [weak self] in await self?.styleVisitedLinks(in: space) }
    }

    func makePeekPageLease(
        request: BrowserPeekRequest,
        in space: SpaceModel,
        onDownloadOnlyNavigation: @escaping () -> Void
    ) -> MobileBrowserTransientPageLease? {
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
        in space: SpaceModel,
        presentation: TransientPresentation = .quickWindow,
        engineNavigation: BrowserEngineNavigation? = nil,
        onUserActivity: @escaping () -> Void = {},
        onDownloadOnlyNavigation: (() -> Void)? = nil
    ) -> MobileBrowserTransientPageLease? {
        let transientTab = BrowserPageTab.transient(showing: url)
        return host.makeTransientPageLease(
            url: url, in: space, presentation: presentation, engineNavigation: engineNavigation,
            balancedContentRuleLists: contentBlocking.balancedRuleLists ?? [], onUserActivity: onUserActivity,
            onDownloadOnlyNavigation: onDownloadOnlyNavigation
        ) { [weak self] in
            self?.makeTransientPage(tab: transientTab, in: space, presenting: presentation)
        }
    }

    /// Opens a transient request's page through the core, presenting as
    /// `presentation`; `tab` is the request's own stand-in, which no Space
    /// holds. Nil when the core refuses it.
    private func makeTransientPage(
        tab: BrowserPageTab,
        in space: SpaceModel,
        presenting presentation: TransientPresentation
    ) -> MobileBrowserPage? {
        guard
            let opening = browser.openPage(
                in: space.id, for: nil, presenting: presentation, webKit: webKitInputs(for: space))
        else { return nil }
        return host(
            MobileBrowserPage(
                corePage: opening.page,
                webKitPage: webKitPage(opening),
                tab: tab,
                space: space,
                downloadCenter: downloadCenter,
                permissionCenter: permissionCenter,
                serverTrustOverrides: serverTrustOverrides,
                allowsCredentialAccess: !browsingMode.isPrivate,
                isCredentialAccessEnabled: space.settings.credentialPreferences.isEnabled,
                defaultPageZoom: pageZoomPreferences.defaultZoom,
                loadsInitialURL: false,
                loadHTTPAuthenticationCredential: { [loadHTTPAuthenticationCredential] protectionSpace in
                    try await loadHTTPAuthenticationCredential(protectionSpace, space.id)
                },
                saveHTTPAuthenticationCredential: { [saveHTTPAuthenticationCredential] request in
                    try await saveHTTPAuthenticationCredential(request, space.id)
                },
                linkDestinationHost: linkDestinationHost,
                openNewTab: openNewTab,
                openModifiedLink: openModifiedLink,
                openPeek: openPeek
            ))
    }

    /// What WebKit's binding built for a page the core opened.
    private func webKitPage(_ opening: Engines.OpenedPage) -> WebKitEnginePage {
        guard let page = opening.built as? WebKitEnginePage else {
            preconditionFailure("WebKit built something other than its page.")
        }
        return page
    }

    /// A page the core opened, now hosted by this store.
    private func host(_ page: MobileBrowserPage) -> MobileBrowserPage {
        page.host = self
        return page
    }

    /// What WebKit's binding builds a page of `space` from: the Space's
    /// content rules and, where this store keeps nothing, its profile's
    /// ephemeral website data store.
    private func webKitInputs(for space: SpaceModel) -> WebKitPageInputs {
        WebKitPageInputs(
            websiteDataStore: websiteDataStore(for: space.profileID), contentRuleLists: contentRuleLists(for: space))
    }

    @discardableResult
    func adoptTransientPage(
        _ lease: MobileBrowserTransientPageLease,
        as tabID: TabID,
        in space: SpaceModel
    ) -> Bool {
        guard let tab = space.tabs.model(tabID),
            let page = host.adoptTransientPage(lease, as: tabID, in: space, through: browser, prepare: { _ in true })
        else { return false }
        page.adopt(tabID: tabID, tab: BrowserPageTab(tab, images: browser.core.state.favicons))
        host.retain(page, for: tabID)
        activate(page)
        return true
    }

    /// Adopts the web view WebKit pre-made for a popup as a new selected tab in
    /// the opener's Space.
    ///
    /// Declines — leaving the coordinator to route the destination into an
    /// ordinary tab — when the opener is not a resident page of this store. That
    /// covers Peek openers, whose pages belong to transient leases with no tab of
    /// their own, so a popup from one cannot inherit a place in the tab list.
    ///
    /// Per-Space isolation needs no work here: WebKit derives the popup's
    /// configuration from the opener's, so it already carries the opener's
    /// `websiteDataStore`. The Space lookup only
    /// confirms the tab landed in the opener's own profile.
    func adoptPopupWebView(
        configuration: WKWebViewConfiguration,
        requestedURL: URL?,
        opener: MobileBrowserPage,
        selecting: Bool = true
    ) -> WKWebView? {
        guard host.tabID(for: opener) != nil,
            !browser.deletingSpaceIDs.contains(opener.spaceID),
            let registration = popupTabHost.openTab(requestedURL, opener.spaceID, selecting),
            registration.space.id == opener.spaceID,
            registration.space.profileID == opener.profileID
        else { return nil }

        guard
            let page = makeResidentPage(
                for: BrowserPageTab(registration.tab, images: browser.core.state.favicons),
                in: registration.space,
                adoptedConfiguration: configuration
            )
        else {
            popupTabHost.closeTab(registration.tab.id, registration.space.id)
            return nil
        }
        page.markOpenedAsPopup()
        host.retain(page, for: registration.tab.id)
        if selecting { activate(page) }
        return page.webView
    }

    /// Honors `window.close()` by closing the popup's tab through the same store
    /// path the tab list's close control uses. The page itself is released after
    /// the WebKit callback unwinds, because tearing a web view down inside its
    /// own delegate callback is not safe.
    func closeWebContentInitiatedPage(_ page: MobileBrowserPage) {
        guard page.wasOpenedAsPopup, let tabID = host.tabID(for: page) else { return }
        popupTabHost.closeTab(tabID, page.spaceID)
        Task { @MainActor [weak self] in
            self?.unloadPage(for: tabID)
        }
    }

    func discardDownloadOnlyPage(_ page: MobileBrowserPage) {
        guard !host.discardDownloadOnlyTransientPage(page) else { return }
        closeWebContentInitiatedPage(page)
    }

    func routeGeolocationMessage(_ message: WKScriptMessage) {
        guard let sourceWebView = message.webView,
            let page = host.residentPages.first(where: {
                $0.webView === sourceWebView
            })
        else { return }
        page.receiveGeolocationMessage(message)
    }

    func routeBlockedPopupMessage(_ message: WKScriptMessage) {
        guard let sourceWebView = message.webView,
            let page = host.residentPages.first(where: {
                $0.webView === sourceWebView
            })
        else { return }
        page.receiveBlockedPopupMessage(message)
    }

    func routeMediaSessionMessage(_ message: WKScriptMessage) {
        guard let sourceWebView = message.webView,
            let page = host.residentPages.first(where: {
                $0.webView === sourceWebView
            })
        else { return }
        page.receiveMediaSessionMessage(message)
    }

    func goBack() {
        activePage?.goBack()
    }

    func goForward() {
        activePage?.goForward()
    }

    func goBack(to item: BrowserNavigationHistoryItem) {
        activePage?.goBack(toDepth: item.depth)
    }

    func goForward(to item: BrowserNavigationHistoryItem) {
        activePage?.goForward(toDepth: item.depth)
    }

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
    func relockProtectedSpace(_ space: SpaceModel) {
        guard space.settings.requiresAuthentication else { return }
        if activePage?.spaceID == space.id
            || presentedTabIDs.contains(where: { host.page(for: $0)?.spaceID == space.id })
        {
            deactivatePagePresentation()
        }
        host.tabState.removeStates(profileID: space.profileID)
    }

    func reloadOrStop() {
        activePage?.reloadOrStop()
    }

    func reload() {
        activePage?.reload()
    }

    func stopLoading() {
        activePage?.stopLoading()
    }

    func reloadFromOrigin() {
        activePage?.performReload(.fromOrigin)
    }

    func clearSiteDataAndReload() async {
        await activePage?.clearSiteDataAndReload()
    }

    func togglePreferredContentMode() {
        activePage?.togglePreferredContentMode()
    }

    func presentFind() {
        activePage?.presentFind()
    }

    func toggleReaderMode() {
        activePage?.toggleReaderMode()
    }

    func zoomIn() {
        guard activePage?.zoomIn() == true else { return }
        pageZoomFeedbackLabel = pageZoomLabel
        pageZoomFeedbackRevision &+= 1
    }

    func zoomOut() {
        guard activePage?.zoomOut() == true else { return }
        pageZoomFeedbackLabel = pageZoomLabel
        pageZoomFeedbackRevision &+= 1
    }

    func resetZoom() {
        guard activePage?.resetZoom() == true else { return }
        pageZoomFeedbackLabel = pageZoomLabel
        pageZoomFeedbackRevision &+= 1
    }

    func defaultPageZoomDidChange(to zoom: CGFloat) {
        host.defaultPageZoomDidChange(to: zoom)
    }

    @discardableResult
    func copyPageLink() -> Bool {
        guard activePage?.copyPageLink() == true else { return false }
        urlCopyFeedbackRevision &+= 1
        return true
    }

    @discardableResult
    func copyPageLinkAsMarkdown() -> Bool {
        guard activePage?.copyPageLinkAsMarkdown() == true else { return false }
        urlCopyFeedbackRevision &+= 1
        return true
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

    func printPage() {
        activePage?.printPage()
    }

    func exportPDF(to destination: MobileBrowserFileExportDestination) {
        activePage?.exportPDF(to: destination)
    }

    func exportWebArchive(to destination: MobileBrowserFileExportDestination) {
        activePage?.exportWebArchive(to: destination)
    }

    func cancelDownload(_ itemID: UUID) {
        downloadCenter.cancel(itemID)
    }

    func clearDownload(_ itemID: UUID) {
        downloadCenter.clear(itemID)
    }

    func exportDownload(
        _ itemID: UUID,
        to destination: MobileBrowserFileExportDestination
    ) {
        guard let item = downloadCenter.item(itemID),
            item.phase.isComplete,
            let destinationURL = item.destinationURL
        else { return }
        MobileBrowserDialogPresenter.exportDownloadedFile(
            at: destinationURL,
            to: destination
        )
    }

    /// Relieves one squeeze at `level`, once however many signals it sends:
    /// the host lets go of what the core does not decide, then the core,
    /// once each page's media is fresh, unloads the tab pages off screen
    /// longest, as many as a phone or tablet gives back at that level.
    func handleMemoryPressure(
        _ level: MemoryPressureLevel,
        at time: Date = .now
    ) {
        guard memoryPressureCoalescer.shouldHandle(level, at: time) else { return }
        host.relieveMemoryPressure(level, presenting: presentedTabIDs)
        memoryPressureReport?.cancel()
        memoryPressureReport = Task { @MainActor [weak self] in
            // TRANSITIONAL until WebKit reports its pages' media itself: each
            // page is asked now, so the core decides on fresh media.
            for page in self?.host.residentPages ?? [] {
                await page.reportMediaActivity()
            }
            guard !Task.isCancelled, let core = self?.browser.core else { return }
            _ = try? core.send(ReportMemoryPressure(level: level))
        }
    }

    /// Waits until the core heard the latest squeeze.
    func waitForPendingMemoryPressureResponse() async {
        await memoryPressureReport?.value
    }

    /// Handles one kernel pressure event. The raw event has to be captured inside
    /// the dispatch source's own handler, so it arrives here as a value rather than
    /// being read back off the source.
    func handleMemoryPressureEvent(
        _ event: DispatchSource.MemoryPressureEvent,
        at time: Date = .now
    ) {
        handleMemoryPressure(
            event.contains(.critical) ? .critical : .warning,
            at: time
        )
    }

    func containsResidentPage(for tabID: TabID) -> Bool {
        _ = residencyRevision
        return host.page(for: tabID) != nil
    }

    func containsResidentPage(
        matching assignment: BrowserTabRuntimeAssignment
    ) -> Bool {
        _ = residencyRevision
        return host.page(matching: assignment) != nil
    }

    func siteThemeIconAccent(for tabID: TabID) -> BrowserTabIconAccent? {
        host.page(for: tabID)?.siteThemeIconAccent
    }

    func siteThemeIconAccent(
        matching assignment: BrowserTabRuntimeAssignment
    ) -> BrowserTabIconAccent? {
        host.page(matching: assignment)?.siteThemeIconAccent
    }

    private func websiteDataStore(for profileID: UUID) -> WKWebsiteDataStore? {
        guard usesEphemeralWebsiteDataStores else { return nil }
        if let dataStore = ephemeralDataStores[profileID] {
            return dataStore
        }
        let dataStore = WKWebsiteDataStore.nonPersistent()
        ephemeralDataStores[profileID] = dataStore
        return dataStore
    }

    /// Opens a page for `tab` in `space` through the core and hosts what WebKit
    /// built; nil when the core refuses the tab a page. `adoptedConfiguration`
    /// is WebKit's own popup configuration, which must be used exactly as
    /// handed over; passing it replaces the configuration the binding would
    /// otherwise assemble and leaves the first navigation to WebKit.
    private func makeResidentPage(
        for tab: BrowserPageTab,
        in space: SpaceModel,
        adoptedConfiguration: WKWebViewConfiguration? = nil,
        loadsInitialURL: Bool = true
    ) -> MobileBrowserPage? {
        let inputs =
            adoptedConfiguration.map { .popup($0, contentRuleLists: contentRuleLists(for: space)) }
            ?? webKitInputs(for: space)
        guard let opening = browser.openPage(in: space.id, for: tab.id, webKit: inputs) else { return nil }
        // Restoring WebKit's session state performs its own navigation, so the
        // page must not also start the tab's URL: whichever path runs, exactly one
        // navigation begins. Read only once the core opened the page, so a
        // refused page leaves the archive as it was.
        let archivedState =
            loadsInitialURL && adoptedConfiguration == nil
            ? tab.url.flatMap {
                host.archivedInteractionState(
                    for: BrowserTabRuntimeAssignment(tabID: tab.id, spaceID: space.id, profileID: space.profileID),
                    expecting: $0)
            }
            : nil
        let page = host(
            MobileBrowserPage(
                corePage: opening.page,
                webKitPage: webKitPage(opening),
                tab: tab,
                space: space,
                downloadCenter: downloadCenter,
                permissionCenter: permissionCenter,
                serverTrustOverrides: serverTrustOverrides,
                mediaSessionStore: mediaSessionStore,
                allowsCredentialAccess: !browsingMode.isPrivate,
                isCredentialAccessEnabled: space.settings.credentialPreferences.isEnabled,
                defaultPageZoom: pageZoomPreferences.defaultZoom,
                // The core loads the tab's address once the page is open.
                loadsInitialURL: false,
                loadHTTPAuthenticationCredential: { [loadHTTPAuthenticationCredential] protectionSpace in
                    try await loadHTTPAuthenticationCredential(protectionSpace, space.id)
                },
                saveHTTPAuthenticationCredential: { [saveHTTPAuthenticationCredential] request in
                    try await saveHTTPAuthenticationCredential(request, space.id)
                },
                linkDestinationHost: linkDestinationHost,
                openNewTab: openNewTab,
                openModifiedLink: openModifiedLink,
                openPeek: openPeek
            ))
        // Anything WebKit will not take falls through to the plain load the page
        // would otherwise start, which the core asks its engine for.
        if loadsInitialURL, adoptedConfiguration == nil, let url = tab.url,
            archivedState.map({ !page.restoreInteractionState($0, expecting: url) }) ?? true
        {
            page.corePage.navigate(to: url.absoluteString)
        }
        return page
    }

    private func contentRuleLists(for space: SpaceModel) -> [WKContentRuleList] {
        contentBlocking.ruleLists(for: space.settings.browsingPreferences.contentBlocking)
    }

    /// Focuses a page that is already on screen, or brings one on screen beside
    /// the cards already there.
    ///
    /// Popup adoption and extension selection reach focus without going through
    /// `select`, one frame ahead of the store-driven reselection that settles the
    /// presented set properly. Adding the tab here rather than replacing the set
    /// is what keeps that frame from rendering a card with no page.
    private func activate(_ page: MobileBrowserPage) {
        var presented = presentedTabIDs
        if !presented.contains(page.tabID) {
            presented.append(page.tabID)
        }
        activate(page, presenting: presented)
    }

    /// Puts `presented` on screen in order with `page` focused.
    private func activate(_ page: MobileBrowserPage, presenting presented: [TabID]) {
        // Guarded: `select` runs on every selection synchronization, and an
        // unconditional write would remount a card's host on changes that left
        // membership exactly as it was.
        if presentedTabIDs != presented {
            presentedTabIDs = presented
        }
        activePage = page
    }

    /// Writes out the WebKit session state of every resident page. The app calls
    /// this when a scene stops being active, so state survives a termination
    /// before an inactive page is unloaded.
    func archiveResidentTabStates() {
        host.archiveResidentTabStates()
    }

    func flushPendingTabStateWrites() async {
        await host.flushPendingTabStateWrites()
    }

    /// Listens for the kernel's own pressure events. UIKit's memory warning only
    /// reaches a foreground app and arrives late, so on iOS — where the system
    /// kills an app rather than swapping — this is the signal that gets ahead of a
    /// termination. It stays a thin wire: everything it decides is the level.
    private func installMemoryPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            // `dispatch_source_get_data` is only defined while this handler is
            // running: read after a hop it answers zero, and critical pressure
            // would forever look like a warning. The source runs on the main
            // queue, so the event is captured and handled without one.
            MainActor.assumeIsolated {
                guard let self, let source = self.memoryPressureSource else { return }
                self.handleMemoryPressureEvent(source.data)
            }
        }
        memoryPressureSource = source
        source.resume()
    }
}

extension MobileBrowserPageStore: BrowserTabCopying {
    func prepareTabCopy(from source: TabState, copyID: TabID, in space: BrowserSpaceRuntimeAssignment) {
        host.prepareTabCopy(from: source, copyID: copyID, in: space)
    }
}

extension MobileBrowserPageStore: BrowserTabLinkProviding {
    func liveLinkURL(for assignment: BrowserTabRuntimeAssignment) -> URL? {
        host.liveLinkURL(for: assignment)
    }
}
