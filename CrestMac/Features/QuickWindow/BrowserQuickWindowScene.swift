import SwiftUI

struct BrowserQuickWindowScene: View {
    @Binding var request: BrowserQuickWindowRequest?
    let browser: BrowserStore
    let pages: BrowserPagePool?
    let spaceAccess: BrowserSpaceAccessController
    let pagePoolRegistry: BrowserPagePoolRegistry?
    let preferences: BrowserTransientBrowsingPreferences
    let previewModel: BrowserQuickWindowModel?
    let windowCoordinator: BrowserMacWindowCoordinator?
    /// Opens a link or document this scene receives where the core places it.
    let externalOpening: BrowserMacExternalOpening?

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var isRoutingExternalURL = false

    init(
        request: Binding<BrowserQuickWindowRequest?>,
        browser: BrowserStore,
        pages: BrowserPagePool,
        spaceAccess: BrowserSpaceAccessController,
        pagePoolRegistry: BrowserPagePoolRegistry,
        windowCoordinator: BrowserMacWindowCoordinator,
        externalOpening: BrowserMacExternalOpening,
        preferences: BrowserTransientBrowsingPreferences? = nil
    ) {
        _request = request
        self.browser = browser
        self.pages = pages
        self.spaceAccess = spaceAccess
        self.pagePoolRegistry = pagePoolRegistry
        self.windowCoordinator = windowCoordinator
        self.externalOpening = externalOpening
        self.preferences = preferences ?? .production(core: browser.core)
        previewModel = nil
    }

    init(
        previewing request: Binding<BrowserQuickWindowRequest?>,
        model: BrowserQuickWindowModel,
        spaceAccess: BrowserSpaceAccessController
    ) {
        _request = request
        browser = model.browser
        pages = nil
        self.spaceAccess = spaceAccess
        pagePoolRegistry = nil
        windowCoordinator = nil
        externalOpening = nil
        preferences = .isolated
        previewModel = model
    }

    var body: some View {
        BrowserQuickWindowSceneContent(
            request: request,
            context: resolvedContext,
            isRoutingExternalURL: isRoutingExternalURL,
            spaceAccess: spaceAccess,
            pagePoolRegistry: pagePoolRegistry,
            preferences: preferences,
            previewModel: previewModel,
            requestLifecycle: requestLifecycle,
            openBrowserWindow: openBrowserWindow
        )
        .onOpenURL { url in
            Task { await routeExternalURL(url) }
        }
    }

    private var contextResolver: BrowserQuickWindowContextResolver? {
        guard let pages, let pagePoolRegistry else { return nil }
        return BrowserQuickWindowContextResolver(
            browser: browser,
            pages: pages,
            pagePoolRegistry: pagePoolRegistry
        )
    }

    private var resolvedContext: BrowserQuickWindowBrowsingContext? {
        guard let request, let contextResolver else { return nil }
        return contextResolver.context(for: request)
    }

    private var requestLifecycle: BrowserQuickWindowRequestLifecycle {
        let requestBinding = $request
        return BrowserQuickWindowRequestLifecycle(
            isCurrent: { expected in
                requestBinding.wrappedValue?
                    .hasSamePresentationIdentity(as: expected) == true
            },
            replace: { expected, revised in
                guard
                    requestBinding.wrappedValue?
                        .hasSamePresentationIdentity(as: expected) == true
                else { return false }
                requestBinding.wrappedValue = revised
                return true
            }
        )
    }

    /// Opens a link or document SwiftUI delivered to this scene, which it
    /// does when no browser window is open, where the core places it: a link
    /// that opens in a Quick Window shows here, and anything that goes to a
    /// browser window takes this one's place.
    private func routeExternalURL(_ url: URL) async {
        let accepted =
            url.isFileURL ? BrowserCorePolicy.acceptsLocalDocument(url) : BrowserCorePolicy.acceptsExternalURL(url)
        guard accepted, let externalOpening, let windowCoordinator else { return }
        isRoutingExternalURL = true
        defer { isRoutingExternalURL = false }
        let scenes = BrowserMacExternalOpening.Presenter.scenes(openWindow, coordinator: windowCoordinator)
        let requestBinding = $request
        await externalOpening.open(
            [url],
            presenter: BrowserMacExternalOpening.Presenter(
                showWindow: { opened in
                    scenes.showWindow(opened)
                    dismissWindow()
                },
                openQuickWindow: { replacement in requestBinding.wrappedValue = replacement }))
    }

    private func openBrowserWindow() {
        let destinationBrowser = resolvedContext?.browser ?? browser
        if windowCoordinator?.activateExistingWindow(for: destinationBrowser) == true { return }
        openWindow(
            id: BrowserSceneID.browser.rawValue,
            value: BrowserMacWindowRequest.normal(sourceWindowID: nil)
        )
    }
}
