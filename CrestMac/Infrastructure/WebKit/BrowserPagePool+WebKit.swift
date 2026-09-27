import Foundation
import WebKit

/// The pool's WebKit hosting: each WebKit page's configuration, its private
/// website data store and content rules, popups WebKit creates itself, and
/// script messages a popup posts to its opener's shared handlers.
extension BrowserPagePool {
    // MARK: - Actions - Pages

    /// What WebKit's binding builds a page of `space` from: the Space's
    /// content rules and, where this pool keeps nothing, its profile's
    /// ephemeral website data store.
    func webKitInputs(for space: SpaceModel) -> WebKitPageInputs {
        WebKitPageInputs(
            websiteDataStore: websiteDataStore(for: space.profileID), contentRuleLists: contentRuleLists(for: space))
    }

    /// What WebKit's binding builds a page of Space `spaceID` from when the
    /// core moves the page to WebKit; nil once the Space is gone.
    func webKitInputs(forSpaceID spaceID: SpaceID) -> WebKitPageInputs? {
        browser.spaceModel(spaceID).map(webKitInputs(for:))
    }

    /// Adopts the web view WebKit pre-made for a popup as a new tab in the
    /// opener's Space, selected unless `selecting` is false.
    ///
    /// Per-Space isolation needs no work here: WebKit derives the popup's
    /// configuration from the opener's, so it already carries the opener's
    /// `websiteDataStore` and web extension controller. The Space lookup only
    /// confirms the tab landed in the opener's own profile.
    func adoptPopupWebView(
        configuration: WKWebViewConfiguration,
        requestedURL: URL?,
        opener: BrowserPage,
        selecting: Bool = true
    ) -> WKWebView? {
        // A popup keeps the opener's configuration, which carries its website
        // data store, content controller and web extension controller.
        adoptPopupPage(requestedURL: requestedURL, opener: opener, selecting: selecting) { space in
            .popup(configuration, contentRuleLists: contentRuleLists(for: space))
        }?.webKitView
    }

    private func contentRuleLists(for space: SpaceModel) -> [WKContentRuleList] {
        contentBlocking.ruleLists(for: space.settings.browsingPreferences.contentBlocking)
    }

    private func websiteDataStore(for profileID: UUID) -> WKWebsiteDataStore? {
        guard usesEphemeralWebsiteDataStores else { return nil }
        if let dataStore = profileDataStores.ephemeral[profileID] {
            return dataStore
        }
        let dataStore = WKWebsiteDataStore.nonPersistent()
        profileDataStores.ephemeral[profileID] = dataStore
        return dataStore
    }

    // MARK: - Actions - Content blocking

    func prepareContentBlocking() async {
        await contentBlocking.prepare()
    }

    /// Gives every page its Space's content blocking in the window's
    /// workspace, reloading presented pages only when their Space's protection
    /// level changes.
    func reconcileContentBlocking() async {
        let update = await contentBlocking.reconcile(in: browser.workspaceModel)
        for (tabID, runtime) in runtimeStore.runtimes {
            let page = runtime.page
            let isPresentedPage = runtimeStore.presentedTabIDs.contains(tabID)
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

    // MARK: - Actions - Script message routing

    // A popup shares its opener's `WKUserContentController`, so its bridges
    // post to the opener's handlers; each message goes to the page whose web
    // view sent it.

    func routeHostedWebNotificationMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveHostedWebNotificationMessage(message)
    }

    func routeGeolocationMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveGeolocationMessage(message)
    }

    func routeBlockedPopupMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveBlockedPopupMessage(message)
    }

    func routeMediaSessionMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveMediaSessionMessage(message)
    }

    private func residentPage(sending message: WKScriptMessage) -> BrowserPage? {
        guard let sourceWebView = message.webView else { return nil }
        return residentPages.first { $0.webKitView === sourceWebView }
    }
}
