import Foundation
import WebKit

/// A window's owner of the pages its workspace's host keeps: a Mac window's
/// page pool, or an iPhone or iPad scene's page store. What every owner does
/// the same way lives here, over the host and the window's read model; each
/// platform keeps only presentation and what its windowing needs.
@MainActor
protocol BrowserPageOwner: AnyObject, BrowserTabCopying, BrowserTabLinkProviding, BrowserSpaceDataDeleting {
    /// The window whose read model the owner follows.
    var browser: BrowserStore { get }
    /// The pages the owner's workspace keeps.
    var host: BrowserPageHost { get }
    /// The focused card's page, which the page commands act on.
    var activePage: BrowserPlatformPage? { get }
    /// Every tab whose page some window over the host presents now.
    var presentedTabIDsAcrossWindows: Set<TabID> { get }
    /// The built-in content blocking the owner applies to its pages.
    var contentBlocking: BrowserContentBlockingController { get }
    /// The per-profile engine state the owner's pages keep beside the host.
    var profileDataStores: BrowserPageProfileDataStores { get }
    /// Whether every page keeps its website data in memory only.
    var usesEphemeralWebsiteDataStores: Bool { get }
    var downloadCenter: BrowserDownloadCenter { get }
    var permissionCenter: BrowserSitePermissionCenter { get }

    /// A lease on a page the core opens in `space` for a transient request.
    func makeTransientPageLease(
        url: URL,
        in space: SpaceModel,
        presentation: TransientPresentation,
        engineNavigation: BrowserEngineNavigation?,
        onUserActivity: @escaping () -> Void,
        onDownloadOnlyNavigation: (() -> Void)?
    ) -> BrowserPlatformTransientPageLease?
}

// MARK: - Reconciliation

extension BrowserPageOwner {
    /// What the owner's runtime state follows in the window's workspace: tab
    /// icons, content blocking and credential access, compared between
    /// changes so each is reconciled only when it moved.
    var runtimeProjection: BrowserRuntimeSessionProjection {
        BrowserRuntimeSessionProjection(workspace: browser.workspaceModel, images: browser.core.state.favicons)
    }

    /// Releases the pages of tabs the window's workspace no longer holds and
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
}

// MARK: - Content blocking and WebKit inputs

extension BrowserPageOwner {
    var contentBlockingErrorDescription: String? { contentBlocking.errorDescription }

    var serverTrustOverrides: BrowserServerTrustOverrideStore { profileDataStores.serverTrustOverrides }

    func prepareContentBlocking() async {
        await contentBlocking.prepare()
    }

    /// Gives every page its Space's content blocking in the window's
    /// workspace, reloading presented pages only when their Space's
    /// protection level changes.
    func reconcileContentBlocking() async {
        let update = await contentBlocking.reconcile(in: browser.workspaceModel)
        let presented = presentedTabIDsAcrossWindows
        for (tabID, runtime) in host.runtimes {
            let page = runtime.page
            page.applyContentBlocking(
                policy: update.policy(for: page.spaceID),
                balancedRuleLists: contentBlocking.balancedRuleLists ?? [],
                activation: update.activation(for: page.spaceID, isPresented: presented.contains(tabID))
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

    /// What WebKit's binding builds a page of `space` from: the Space's
    /// content rules and, where the owner keeps nothing on disk, its
    /// profile's ephemeral website data store.
    func webKitInputs(for space: SpaceModel) -> WebKitPageInputs {
        WebKitPageInputs(
            websiteDataStore: websiteDataStore(for: space.profileID), contentRuleLists: contentRuleLists(for: space))
    }

    /// What WebKit's binding builds a page of Space `spaceID` from when the
    /// core moves the page to WebKit; nil once the Space is gone.
    func webKitInputs(forSpaceID spaceID: SpaceID) -> WebKitPageInputs? {
        browser.spaceModel(spaceID).map(webKitInputs(for:))
    }

    /// The content rules `space` applies.
    func contentRuleLists(for space: SpaceModel) -> [WKContentRuleList] {
        contentBlocking.ruleLists(for: space.settings.browsingPreferences.contentBlocking)
    }

    /// The profile's ephemeral website data store, or nil where the owner's
    /// pages keep their profile's own store.
    func websiteDataStore(for profileID: UUID) -> WKWebsiteDataStore? {
        guard usesEphemeralWebsiteDataStores else { return nil }
        return profileDataStores.ephemeralStore(for: profileID)
    }
}

// MARK: - Space data

extension BrowserPageOwner {
    /// Releases the owner's pages in the Space `space` names, then has every
    /// engine erase its profile's data.
    func deleteData(for space: BrowserSpaceRuntimeAssignment) async throws {
        try await host.deleteData(for: space, on: browser.core, ephemeral: usesEphemeralWebsiteDataStores) {
            await releaseWindowRuntime(for: space)
            serverTrustOverrides.removeApprovals(for: space.profileID)
        }
        permissionCenter.reset(spaceID: space.spaceID)
    }

    /// Lets go of every page, download record and ephemeral store the owner
    /// keeps for the Space `space` names.
    func releaseWindowRuntime(for space: BrowserSpaceRuntimeAssignment) async {
        guard host.spacesReleasingData.insert(space.spaceID).inserted else {
            host.nativeTabs.remove(in: space.spaceID)
            return
        }
        defer { host.spacesReleasingData.remove(space.spaceID) }
        await host.releasePages(of: space)
        downloadCenter.deleteRecords(profileID: space.profileID, spaceID: space.spaceID)
        if usesEphemeralWebsiteDataStores {
            profileDataStores.releaseEphemeralStore(for: space.profileID)
        }
    }

    /// Lets go of everything a private workspace kept in the Spaces `spaces`
    /// names: its pages, download records, site permissions, fallback icons
    /// and ephemeral website data.
    func releasePrivateBrowsingData(in spaces: [BrowserSpaceRuntimeAssignment]) {
        host.closePrivateBrowsingSession()
        for space in spaces {
            downloadCenter.deleteRecords(profileID: space.profileID, spaceID: space.spaceID)
            permissionCenter.reset(spaceID: space.spaceID)
            Task {
                await BrowserFaviconFallbackLoader.shared.removeAll(for: space.profileID)
            }
        }
        profileDataStores.releaseAllEphemeralStores()
    }
}

// MARK: - Residency and tab state

extension BrowserPageOwner {
    /// Every page resident in the host's tabs.
    var residentPages: [BrowserPlatformPage] { host.residentPages }

    var retainedTransientPageCount: Int { host.retainedTransientPageCount }

    func containsResidentPage(for tabID: TabID) -> Bool {
        _ = host.revision
        return host.page(for: tabID) != nil
    }

    func containsResidentPage(matching assignment: BrowserTabRuntimeAssignment) -> Bool {
        _ = host.revision
        return host.page(matching: assignment) != nil
    }

    func siteThemeIconAccent(for tabID: TabID) -> BrowserTabIconAccent? {
        host.page(for: tabID)?.siteThemeIconAccent
    }

    func siteThemeIconAccent(matching assignment: BrowserTabRuntimeAssignment) -> BrowserTabIconAccent? {
        host.page(matching: assignment)?.siteThemeIconAccent
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
    func unloadPage(for tabID: TabID, matching assignment: BrowserSpaceRuntimeAssignment) -> Bool {
        host.unloadPage(for: tabID, matching: assignment)
    }

    /// Releases a Space's resident pages without archiving them. Normal Space
    /// switching and locking preserve residency and do not call this teardown.
    func unloadPages(in spaceID: SpaceID) {
        host.unloadPages(in: spaceID)
    }

    func flushPendingTabStateWrites() async {
        await host.flushPendingTabStateWrites()
    }

    func pullFavicon(for tabID: TabID) async -> (data: Data, iconAccent: BrowserTabIconAccent?)? {
        await host.pullFavicon(for: tabID)
    }

    func pullFavicon(
        for tabID: TabID, matching assignment: BrowserSpaceRuntimeAssignment
    ) async -> (data: Data, iconAccent: BrowserTabIconAccent?)? {
        await host.pullFavicon(for: tabID, matching: assignment)
    }

    func prepareTabCopy(from source: TabState, copyID: TabID, in space: BrowserSpaceRuntimeAssignment) {
        host.prepareTabCopy(from: source, copyID: copyID, in: space)
    }

    func liveLinkURL(for assignment: BrowserTabRuntimeAssignment) -> URL? {
        host.liveLinkURL(for: assignment)
    }
}

// MARK: - Transient leases

extension BrowserPageOwner {
    /// The Peek's lease on a page for `request` in `space`, reused while the
    /// Peek asks for the same request.
    func makePeekPageLease(
        request: BrowserPeekRequest,
        in space: SpaceModel,
        onDownloadOnlyNavigation: @escaping () -> Void
    ) -> BrowserPlatformTransientPageLease? {
        guard request.assignment == BrowserSpaceRuntimeAssignment(space: space) else { return nil }
        return host.peekPageLease(for: request) {
            makeTransientPageLease(
                url: request.url, in: space, presentation: .peek, engineNavigation: request.engineNavigation,
                onUserActivity: {}, onDownloadOnlyNavigation: onDownloadOnlyNavigation)
        }
    }

    func retainPeekPages(for requests: [BrowserPeekRequest]) {
        host.retainPeekPages(for: requests)
    }

    func pruneTransientLeases() {
        host.pruneTransientLeases()
    }
}

// MARK: - Page commands

extension BrowserPageOwner {
    var canGoBack: Bool { activePage?.live.canGoBack == true }
    var canGoForward: Bool { activePage?.live.canGoForward == true }
    var backHistory: [BrowserNavigationHistoryItem] { activePage?.backHistory ?? [] }
    var forwardHistory: [BrowserNavigationHistoryItem] { activePage?.forwardHistory ?? [] }

    var pageZoomLabel: String {
        BrowserPageZoomPolicy.percentageLabel(for: activePage?.pageZoom ?? 1)
    }

    var readerModeState: BrowserReaderModeState {
        activePage?.readerModeState ?? .unavailable
    }

    var readerModeActionTitle: LocalizedStringResource {
        readerModeState.isActive ? "Hide Reader" : "Show Reader"
    }

    func goBack() { activePage?.goBack() }
    func goForward() { activePage?.goForward() }
    func goBack(to item: BrowserNavigationHistoryItem) { activePage?.goBack(toDepth: item.depth) }
    func goForward(to item: BrowserNavigationHistoryItem) { activePage?.goForward(toDepth: item.depth) }

    func stopLoading() {
        activePage?.stopLoading()
    }

    func clearSiteDataAndReload() async {
        await activePage?.clearSiteDataAndReload()
    }

    func presentFind() {
        activePage?.presentFind()
    }

    func toggleReaderMode() {
        activePage?.toggleReaderMode()
    }

    @discardableResult
    func copyPageLinkAsMarkdown() -> Bool {
        activePage?.copyPageLinkAsMarkdown() == true
    }

    func printPage() {
        activePage?.printPage()
    }

    /// Gives every page the host keeps the new default zoom.
    func defaultPageZoomDidChange(to zoom: CGFloat) {
        host.defaultPageZoomDidChange(to: zoom)
    }
}

// MARK: - Script messages

extension BrowserPageOwner {
    // A popup shares its opener's `WKUserContentController`, so its bridges
    // post to the opener's handlers; each message goes to the page whose web
    // view sent it.

    func routeGeolocationMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveGeolocationMessage(message)
    }

    func routeBlockedPopupMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveBlockedPopupMessage(message)
    }

    func routeMediaSessionMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveMediaSessionMessage(message)
    }

    /// The resident page whose web view posted `message`.
    func residentPage(sending message: WKScriptMessage) -> BrowserPlatformPage? {
        guard let sourceWebView = message.webView else { return nil }
        return host.residentPages.first { $0.webKitView === sourceWebView }
    }
}
