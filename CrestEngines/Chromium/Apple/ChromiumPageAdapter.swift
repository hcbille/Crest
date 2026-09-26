#if CREST_CHROMIUM_HOST
    import AppKit

    /// The desktop Chromium adapter for one page. The engine presents its page
    /// through `ChromiumNativePage` as the page's engine-neutral events and asks
    /// through its handlers; this connects both to the page.
    @MainActor
    final class ChromiumPageAdapter: BrowserPageEngineAdapter {
        // MARK: - Variables

        let native: ChromiumNativePage
        private weak var page: BrowserPage?
        var engine: any BrowserPageEngine { native }
        let enginePage: EnginePage

        /// The engine reports hovered links itself.
        private(set) lazy var linkHover: BrowserLinkHoverController? =
            BrowserLinkHoverController(contentView: native.nativeView)
        private(set) lazy var linkDrag: BrowserLinkDragController? = BrowserLinkDragController(
            nativeView: native.nativeView,
            context: { [weak self] in self?.page?.navigationContext },
            handle: { [weak self] event in self?.page?.handleLinkDrag(event) })
        private(set) lazy var pictureInPicture: (any BrowserPagePictureInPictureController)? =
            ChromiumPictureInPicturePageController(native: native)
        // Chromium presents favicons and its error pages itself; reader and
        // content blocking are unavailable.
        var readerModeSession: BrowserReaderModeSession? { nil }
        var faviconSession: BrowserFaviconSession? { nil }
        var isContentBlockingActive: Bool { false }
        /// Chromium's binding reports the page's navigations to the core itself.
        var reporter: EnginePageReporter? { nil }
        /// Fills go through the engine's content scripting.
        var credentialEvaluator: BrowserCredentialSession.Evaluate? { nil }

        // MARK: - Initializers

        init(_ native: ChromiumNativePage) {
            self.native = native
            enginePage = native.makeEnginePage()
        }

        // MARK: - Actions - Lifecycle

        func makeMediaSessionCoordinator(
            for page: BrowserPage,
            store: BrowserMediaSessionStore
        ) -> BrowserMediaSessionPageCoordinator? { nil }

        func attach(to page: BrowserPage, allowsCredentialAccess: Bool) {
            self.page = page
            native.profileID = page.profileID
            native.observer = { [weak page] event in page?.receive(event) }
            native.linkHandler = { [weak page] name, destination, label in
                guard let page, let action = ChromiumLinkAction(rawValue: name) else { return false }
                return page.performEngineLinkAction(action.pageAction, destination: destination, label: label)
            }
            native.contextMenuActions = { [weak page] url, selection in
                page?.contextMenuActions(linkURL: url, selectionText: selection).map(\.engineValues) ?? []
            }
            native.contextMenuAction = { [weak page] identifier, url, selection in
                page?.performContextMenuAction(
                    identifier: identifier, linkURL: url, selectionText: selection) ?? false
            }
            native.promptPresenter = page
            native.protectedLinkHandler = { [weak page] destination in
                page?.protectedLinkAction(to: destination)
            }
            native.modifiedLinkHandler = { [weak page, weak native] destination, modifiers, token in
                guard let page else { return (.navigate, nil) }
                return page.modifiedLinkDecision(
                    to: destination, modifiers: BrowserEngineLinkModifiers(rawValue: modifiers),
                    navigationToken: token, discard: { native?.discardNavigation(token) })
            }
            linkDrag?.observeNativeMouseDown()
        }

        func detach(from page: BrowserPage) {
            pictureInPicture?.invalidate()
            native.dispose()
        }

        func setPrivateBrowsing(_ isPrivate: Bool) { native.isPrivateBrowsing = isPrivate }
        func adoptEngineCreatedPage(_ token: String) -> Bool { native.adopt(token) }

        // MARK: - Actions - Engine-owned services

        /// Chromium's page view takes focus through its own responder chain.
        func install(_ focusRestoration: BrowserWebFocusRestorationController) {}
        /// The engine reports input as a `user_activity` event.
        func monitorUserActivity(for page: BrowserPage) {}
        /// Chromium styles visited links from its own history.
        func styleVisitedLinks(history: [BrowserHistoryEntry]) async {}
        func prepareForNavigation() {}
        /// The engine enforces site permissions itself; the page's permission
        /// session has already applied the change through `applySitePermission`.
        func sitePermissionDidChange(_ permission: SitePermission, on page: BrowserPage) {}
    }

    /// The link actions the engine's own context menu and drag ask about.
    private enum ChromiumLinkAction: String {
        case canSearch = "can_search"
        case search
        case canPeek = "can_peek"
        case peek
        case canSplit = "can_split"
        case split
        case drag

        var pageAction: BrowserEngineLinkAction {
            switch self {
            case .canSearch: .canSearch
            case .search: .search
            case .canPeek: .canPeek
            case .peek: .peek
            case .canSplit: .canSplit
            case .split: .split
            case .drag: .drag
            }
        }
    }

    extension BrowserPage {
        /// The Chromium page behind this page, or nil when another engine hosts it.
        var chromiumPage: ChromiumNativePage? { (engineAdapter as? ChromiumPageAdapter)?.native }
    }

    extension BrowserEnginePageAdoption {
        /// The page the engine offered.
        init(offer: PageOffered) {
            self.init(
                token: offer.adoptionID.uuidString,
                profileID: offer.profileID,
                sourcePageID: offer.sourcePageID?.uuidString,
                windowID: offer.windowID,
                spaceID: offer.spaceID,
                url: URL(string: offer.url),
                foreground: offer.foreground
            )
        }
    }
    /// Chromium's browser Media Session can ask the active video player to enter
    /// PiP without page JavaScript or a synthetic click. The floating surface is
    /// still Chromium-owned; this controller only follows Crest's tab lifecycle.
    @MainActor
    private final class ChromiumPictureInPicturePageController:
        BrowserPagePictureInPictureController, BrowserAutomaticPictureInPictureClient
    {
        private let native: ChromiumNativePage
        private let coordinator: BrowserAutomaticPictureInPictureCoordinator
        private var completion: (@MainActor (Bool) -> Void)?
        private var check: Task<Void, Never>?

        var isPictureInPictureActive: Bool { native.currentMediaActivity?.contains(.pictureInPicture) == true }
        var protectsPageResidency: Bool { isPictureInPictureActive || completion != nil }
        var canAutomaticallyEnterPictureInPicture: Bool {
            native.currentMediaActivity.map { $0.contains(.playing) && !$0.contains(.pictureInPicture) } == true
        }

        init(native: ChromiumNativePage, coordinator: BrowserAutomaticPictureInPictureCoordinator = .shared) {
            self.native = native
            self.coordinator = coordinator
            coordinator.register(self)
        }

        func leaveTab() {
            coordinator.request(from: self)
        }
        func returnToTab() { coordinator.cancel(self) }

        func beginAutomaticPictureInPicture(completion: @escaping @MainActor (Bool) -> Void) {
            guard native.enterPictureInPicture() else {
                completion(false)
                return
            }
            self.completion = completion
            check = Task { @MainActor [weak self] in
                // Media Session sends the request to the renderer. Check its
                // resulting browser state before releasing the reservation.
                do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                guard let self else { return }
                self.completion?(self.isPictureInPictureActive)
                self.completion = nil
                self.check = nil
            }
        }

        func cancelAutomaticPictureInPicture() {
            check?.cancel()
            check = nil
            completion?(false)
            completion = nil
        }

        func invalidate() {
            coordinator.cancel(self)
        }
    }
#endif
