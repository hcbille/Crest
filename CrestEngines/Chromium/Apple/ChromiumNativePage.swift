#if CREST_CHROMIUM_HOST
    import AppKit
    import Observation
    import PDFKit

    /// Hosts the view of one Chromium page and makes the page's direct calls:
    /// history, find, zoom, capture and the rest. Chromium's C++ binding creates,
    /// loads and closes the page when the core asks, under the identity the
    /// core gave it, and tells the core what it does; this reports nothing. It
    /// presents the page to this one: what its view shows, as the page's
    /// engine-neutral events.
    @Observable @MainActor
    final class ChromiumNativePage: BrowserPageEngine {
        let registration = BrowserEngineRegistration.chromium
        /// The core's identity for this page.
        let pageID: UUID
        /// The name the engine uses for this page: the core's identity.
        let id: String
        let surface = ChromiumNativePageView()
        var isPrivateBrowsing: Bool
        /// The profile of the page's Space, once its owner names it.
        var profileID: UUID?
        /// The browser operations this page may ask for, such as the Space a
        /// Chrome Web Store listing installs into. Weak: the composition owns it.
        private weak var hostCommands: (any BrowserEngineHostCommands)?
        /// A Settings page of the engine's own, such as its flags page, which no
        /// tab owns and the core never hears of: it opens once its view is in a
        /// window. TRANSITIONAL until such pages open through the core.
        private let isStandalone: Bool
        /// The engine that hosts the page, which its direct requests go to.
        private weak var engine: ChromiumEngine?
        var observer: (BrowserPageEngineEvent) -> Void
        var linkHandler: (String, URL, String) -> Bool = { _, _, _ in false }
        var contextMenuActions: (URL?, String?) -> [[String: String]] = { _, _ in [] }
        var contextMenuAction: (String, URL?, String?) -> Bool = { _, _, _ in false }
        /// The platform's page hosting this one, which shows the person the
        /// core's questions about it.
        weak var promptPresenter: (any BrowserPromptPresenting)?
        var protectedLinkHandler: (URL) -> (() -> Void)? = { _ in nil }
        var modifiedLinkHandler: (URL, Int, String) -> (LinkNavigationDecision, (() -> Void)?) = { _, _, _ in
            (.navigate, nil)
        }
        private var host: (any CrestMacShell)?
        /// What a standalone page loads once it opens.
        private var requestedURL: URL?
        private var opening = false
        private var created = false
        private var disposed = false
        /// What waits for the engine: each capture and export by its identity.
        private var captures: [UUID: @MainActor (NSImage?) -> Void] = [:]
        private var exports: [UUID: CheckedContinuation<Data, any Error>] = [:]
        private var evaluations: [UUID: CheckedContinuation<String?, Never>] = [:]

        /// A page the core opened, which Chromium's binding creates.
        init(id: UUID, engine: ChromiumEngine) {
            pageID = id
            self.id = id.uuidString
            self.engine = engine
            host = engine.host
            hostCommands = engine.hostCommands
            isPrivateBrowsing = false
            isStandalone = false
            observer = { _ in }
            surface.page = self
            // The binding may have created the page before its view came.
            engine.pages.request(WatchPage(pageID: id))
        }

        /// A Settings page of the engine's own in `profileID`, which opens once
        /// its view is in a window.
        init(standaloneIn profileID: UUID, engine: ChromiumEngine) {
            let id = UUID()
            pageID = id
            self.id = id.uuidString
            self.profileID = profileID
            self.engine = engine
            host = engine.host
            isPrivateBrowsing = false
            isStandalone = true
            observer = { _ in }
            surface.page = self
        }

        /// The page's direct path to the binding, while the engine is running.
        private var pages: NativeEnginePages? { disposed ? nil : engine?.pages }

        /// The shared direct path to this page: going back, reloading, zooming,
        /// finding text and keeping its history, which Chromium restores in
        /// place of the page's first load.
        func makeEnginePage() -> EnginePage {
            guard let engine else { preconditionFailure("A Chromium page came without its engine.") }
            return EnginePage(
                id: pageID, pages: engine.pages, historyFamily: .chromium,
                historyVersion: { [weak self] in self?.host?.engineVersion() })
        }

        var nativeView: NSView { surface }
        func stageNavigation(_ navigation: BrowserEngineNavigation, expecting url: URL) -> Bool {
            guard !isStandalone, !created, !disposed, let host,
                navigation.implementation == registration.implementationId,
                UUID(uuidString: navigation.token) != nil
            else { return false }
            return host.stageNavigation(navigation.token, page: pageID, url: url.absoluteString)
        }
        func discardNavigation(_ token: String) {
            (host ?? CrestChromiumRoot.engineHost)?.discardPendingNavigation(token)
        }
        func showInspector() -> Bool {
            guard created, let pages else { return false }
            return pages.request(OpenInspector(pageID: pageID, panel: nil))
        }
        func toggleInspector(_ panel: BrowserDeveloperPanel, current: BrowserDeveloperPanel?)
            -> BrowserWebInspectorToggleResult
        {
            guard created, let pages else { return .unavailable }
            if pages.request(PageInspected(pageID: pageID)), current == panel {
                return pages.request(CloseInspector(pageID: pageID)) ? .closed : .unavailable
            }
            let starting: InspectorPanel
            switch panel {
            case .console: starting = .console
            case .elements: starting = .elements
            case .network: starting = .network
            }
            guard pages.request(OpenInspector(pageID: pageID, panel: starting)) else { return .unavailable }
            // Chromium selects a starting panel for Console and Elements only. A
            // Network request opens DevTools wherever it was, so report no panel
            // rather than claiming a selection the engine did not make.
            return .opened(panel == .network ? nil : panel)
        }
        private(set) var backHistory: [BrowserNavigationHistoryItem] = []
        private(set) var forwardHistory: [BrowserNavigationHistoryItem] = []
        private(set) var currentURL: URL?
        private(set) var canGoBack = false
        private(set) var canGoForward = false
        /// The binding presents the page's history, loading and failures, so the
        /// page reads them from its presentations.
        var reportsNavigationState: Bool { true }
        var currentMediaActivity: PageMediaActivity? {
            guard created, let pages else { return nil }
            return pages.request(PageMedia(pageID: pageID)).activity
        }
        func mediaActivity() async -> PageMediaActivity? { currentMediaActivity }
        func enterPictureInPicture() -> Bool {
            guard created, let pages else { return false }
            return pages.request(EnterPictureInPicture(pageID: pageID))
        }
        func transferOwnership(to windowID: BrowserWindowID) -> Bool {
            guard created, let pages else { return false }
            return pages.request(MovePageToWindow(pageID: pageID, windowID: windowID))
        }

        func capture(rect: CGRect?, width: CGFloat?, completion: @escaping @MainActor (NSImage?) -> Void) {
            let captureID = UUID()
            let area = rect.flatMap { $0.isEmpty ? nil : $0 }.map {
                PageArea(x: $0.origin.x, y: $0.origin.y, width: $0.size.width, height: $0.size.height)
            }
            guard created, let pages,
                pages.request(CapturePage(pageID: pageID, captureID: captureID, area: area, width: width ?? 0))
            else {
                completion(nil)
                return
            }
            captures[captureID] = completion
        }

        /// The capture the engine made for this page.
        func receive(_ captured: PageCaptured) {
            captures.removeValue(forKey: captured.captureID)?(captured.png.flatMap(NSImage.init(data:)))
        }

        func load(_ request: URLRequest) {
            guard let url = request.url else { return }
            load(url)
        }
        /// The app's own load of `url`, which the binding runs as it runs the
        /// core's LoadPage. A standalone page opens at it.
        func load(_ url: URL) {
            guard !disposed else { return }
            guard isStandalone, !opening else {
                host?.loadPage(pageID, url: url.absoluteString)
                return
            }
            requestedURL = url
            attachIfPossible()
        }

        func attachIfPossible() {
            guard !disposed, let windowID = surface.window?.identifier.flatMap({ UUID(uuidString: $0.rawValue) }),
                let pages
            else { return }
            if created {
                guard pages.request(MovePageToWindow(pageID: pageID, windowID: windowID)),
                    let view = host?.view(forPage: pageID)
                else { return }
                if view.superview !== surface {
                    view.removeFromSuperview()
                    view.frame = surface.bounds
                    view.autoresizingMask = [.width, .height]
                    surface.addSubview(view)
                }
                pages.request(ShowPage(pageID: pageID))
                return
            }
            // The binding creates a page the core opened; a standalone page
            // opens itself, in its window's part of the engine.
            guard isStandalone, !opening, let profileID, let requestedURL else { return }
            opening = true
            let opened = pages.request(
                OpenStandalonePage(
                    pageID: pageID, profileID: profileID, windowID: windowID,
                    url: ChromiumInternalURL.engine(requestedURL.absoluteString)))
            if !opened { creationFailed() }
        }

        /// Makes the page the engine offered as `token` this page, which the
        /// binding then follows instead of creating one.
        func adopt(_ token: String) -> Bool {
            guard !isStandalone, !created, let pages, let adoptionID = UUID(uuidString: token) else { return false }
            return pages.request(AdoptOfferedPage(pageID: pageID, adoptionID: adoptionID))
        }

        /// The engine's find wraps at the end of the page, as Crest's find always
        /// does, and counts every match.
        // MARK: Content bridges

        private var contentScripts: [BrowserContentScript] = []
        private var contentReceivers: [String: @MainActor (BrowserContentMessage) -> Void] = [:]
        var contentScripting: (any BrowserPageContentScripting)? { self }

        private func receive(_ message: ContentMessagePosted) {
            // The body is whatever the bridge posted, so it stays an opaque value.
            guard let receive = contentReceivers[message.handler],
                let body = try? JSONSerialization.jsonObject(with: Data(message.body.utf8), options: .fragmentsAllowed)
            else { return }
            receive(
                BrowserContentMessage(
                    handlerName: message.handler, body: body,
                    frame: BrowserContentFrame(
                        isMainFrame: message.frame.isMainFrame, securityProtocol: message.frame.protocol,
                        host: message.frame.host, port: Int(message.frame.port), handle: message.frame.id as NSString)))
        }

        // Chromium's content-setting values: 1 allows; 0 clears the site's own
        // setting, which leaves the engine's default of blocking.
        func applyAutomaticPopups(_ allowed: Bool) -> Bool {
            guard created, let pages else { return true }
            pages.request(SetSitePermission(pageID: pageID, permission: .popups, allowed: allowed ? true : nil))
            return true
        }

        func respondToInfoBar(_ barID: Int, response: String) -> Bool {
            let answer: InfoBarAnswer
            switch BrowserEngineInfoBar.Response(rawValue: response) {
            case .accept: answer = .accept
            case .cancel: answer = .cancel
            case .dismiss: answer = .dismiss
            case nil: return false
            }
            guard created, let pages else { return false }
            return pages.request(AnswerInfoBar(pageID: pageID, infoBarID: barID, answer: answer))
        }

        /// Rebuilt from the chain the engine verified, so the system certificate
        /// sheet can show it. The trust carries an SSL policy for the page's host.
        var serverTrust: SecTrust? {
            guard created, let pages else { return nil }
            let chain = pages.request(PageCertificates(pageID: pageID)).certificates
            guard !chain.isEmpty else { return nil }
            let certificates = chain.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
            guard certificates.count == chain.count else { return nil }
            var trust: SecTrust?
            let policy = SecPolicyCreateSSL(true, pageHost as CFString?)
            guard SecTrustCreateWithCertificates(certificates as CFArray, policy, &trust) == errSecSuccess else {
                return nil
            }
            return trust
        }
        private var pageHost: String?
        private(set) var mediaSessionLocation: String?
        var mediaSessionTransport: (any BrowserMediaSessionTransport)? { self }

        /// The host keys the content settings it enforces by the permissions'
        /// names: 1 allows, 2 blocks and 0 clears the site's own setting.
        func applySitePermission(_ permission: SitePermission, allowed: Bool?) -> Bool {
            guard Self.enforcedPermissions.contains(permission) else { return false }
            guard created, let pages else { return true }
            pages.request(SetSitePermission(pageID: pageID, permission: permission, allowed: allowed))
            return true
        }

        private static let enforcedPermissions = SitePermission.all.filter(\.isEngineEnforced)

        /// Answers the engine's site permission requests from Crest's record and
        /// prompt.
        /// The engine clears the site its page is showing.
        func refreshFavicon() {
            guard created else { return }
            pages?.request(RefreshPageIcon(pageID: pageID))
        }

        func showBlockedPopups() -> Bool {
            guard created, let pages else { return false }
            return pages.request(ShowBlockedPopups(pageID: pageID))
        }

        /// The extension actions the page's toolbar offers, with each one's state
        /// for the page's own tab.
        var extensions: [BrowserExtensionActionPresentation] {
            guard created, let pages else { return [] }
            return pages.request(PageExtensions(pageID: pageID)).actions.map(BrowserExtensionActionPresentation.init)
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }

        func runExtension(_ extensionID: String, anchor: BrowserExtensionPopupAnchor? = nil) {
            guard created, !disposed else { return }
            let anchor =
                anchor ?? BrowserExtensionPopupAnchor(screenPoint: NSEvent.mouseLocation, sourceWindow: surface.window)
            guard let source = anchor.presentationSource(fallbackWindow: surface.window) else { return }
            if host?.runExtension(extensionID, page: pageID, anchorView: source.view, anchorRect: source.rect) != true {
                CrestChromiumRoot.showNativeNotice(
                    "This extension action is unavailable on this page.", icon: "puzzlepiece.extension")
            }
        }

        /// Whether `extensionID` has a side panel entry for this page's own tab.
        func hasSidePanel(_ extensionID: String) -> Bool {
            guard created, let pages else { return false }
            return pages.request(HasSidePanel(pageID: pageID, extensionID: extensionID))
        }

        /// Creates the panel document and returns its view for the core to mount.
        /// `closed` runs when the panel or its extension host goes away on its own.
        func openSidePanel(_ extensionID: String, closed: @escaping () -> Void) -> NSView? {
            guard created, !disposed, let host else { return nil }
            return host.openSidePanel(extensionID, page: pageID, closed: closed)
        }

        func closeSidePanel() {
            guard created, !disposed else { return }
            host?.closeSidePanel(page: pageID)
        }

        /// Mounts, relayouts or removes the docked DevTools frontend the engine is
        /// offering for this page.
        ///
        /// A docked inspector belongs to the card it inspects, not to the window:
        /// the frontend is a subview of this page's own surface, below the page so
        /// the page can be drawn on top of it at the rectangle the frontend asked
        /// for. Undocking withdraws the offer — Chromium then opens the window the
        /// user asked for — and so does closing the inspector by any route.
        func refreshDevTools() {
            guard !disposed, let host else { return }
            surface.devToolsView = host.devToolsView(page: pageID)
            surface.layoutEngineView()
        }

        /// Where the docked inspector and the page go in a card of `size`.
        func layoutInspector(in size: CGSize) -> InspectorLayout? {
            guard created, let pages else { return nil }
            return pages.request(LayoutInspector(pageID: pageID, width: size.width, height: size.height))
        }

        /// The inspector for this page is going away, whatever closed it. The core
        /// clears its developer-panel selection so the next Console or Elements
        /// command opens an inspector instead of trying to close a closed one.
        func developerPanelDidClose() {
            guard !disposed else { return }
            observer(.developerPanelClosed)
        }

        /// The Chrome Web Store listing this page is showing asked Crest to install
        /// or remove the extension it is about. The engine has already checked that
        /// the extension is the one the page's own URL names, and the destination is
        /// this page's own Space — a listing can never reach another Space or a
        /// private window, which keeps no persistent extension state.
        private func performStoreRequest(_ extensionID: String, removes: Bool) {
            let store = CrestChromiumRoot.extensions
            guard !isPrivateBrowsing, let profileID, let space = hostCommands?.extensionSpace(forProfile: profileID)
            else {
                refreshStoreState()
                return
            }
            let refresh: @MainActor () -> Void = { [weak self] in self?.refreshStoreState() }
            if removes {
                store.confirmRemoval(extensionID, in: space, completion: refresh)
            } else {
                store.install(extensionID, in: space, anchor: surface, completion: refresh)
            }
        }

        /// Restates the listing's install button from Chromium's own registry once
        /// an install review has finished, been canceled, or was never offered.
        private func refreshStoreState() {
            guard created else { return }
            pages?.request(RefreshStoreListing(pageID: pageID))
        }

        static func webStoreExtensionID(_ url: URL?) -> String? {
            guard let url, url.scheme == "https", url.host == "chromewebstore.google.com",
                url.pathComponents.count >= 3, url.pathComponents[1] == "detail",
                let id = url.pathComponents.last, id.count == 32,
                id.allSatisfy({ ("a"..."p").contains(String($0)) })
            else { return nil }
            return id
        }

        /// A page still being created takes the zoom once it exists.
        func detach() {
            guard created else { return }
            pages?.request(HidePage(pageID: pageID))
        }

        /// The page's owner let it go. The core's ClosePage has the binding
        /// close what the engine holds; only a standalone page closes itself.
        func dispose() {
            guard !disposed else { return }
            if isStandalone { engine?.pages.request(CloseStandalonePage(pageID: pageID)) }
            disposed = true
            surface.devToolsView = nil
            for subview in surface.subviews { subview.removeFromSuperview() }
            host = nil
            for (_, completion) in captures { completion(nil) }
            captures = [:]
            for (_, export) in exports { export.resume(throwing: BrowserPageExportError.pageUnavailable) }
            exports = [:]
            for (_, evaluation) in evaluations { evaluation.resume(returning: nil) }
            evaluations = [:]
        }

        private func history(_ entries: [PageHistoryEntry]) -> [BrowserNavigationHistoryItem] {
            entries.enumerated().compactMap { index, entry in
                guard let url = URL(string: entry.url) else { return nil }
                let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return BrowserNavigationHistoryItem(
                    depth: index + 1, title: title.isEmpty ? url.host() ?? url.absoluteString : title, url: url)
            }
        }

        /// What the binding presents of this page, as the page's events.
        func receive(_ presentation: EnginePresentation) {
            guard !disposed else { return }
            switch presentation {
            case .pageViewReady: viewReady()
            case .pageViewUnavailable: creationFailed()
            case .pageViewClosed: observer(.closeRequested)
            case .pageNavigationStarted: observer(.navigationStarted)
            case .pageNavigationCommitted(let committed):
                currentURL = URL(string: committed.url)
                pageHost = currentURL?.host()
                mediaSessionLocation = committed.url
                surface.layoutEngineView()
                observer(.navigationCommitted(currentURL, isLoading: committed.isLoading))
            case .pageNavigationFailed: observer(.navigationFailed)
            case .pageRendererGone: observer(.webContentProcessTerminated)
            case .pageLoadingChanged(let loading):
                observer(.loadingChanged(loading.isLoading))
                observer(.progressChanged(loading.isLoading ? 0.5 : 1))
            case .pageHistoryChanged(let changed):
                backHistory = history(changed.back)
                forwardHistory = history(changed.forward)
                canGoBack = !changed.back.isEmpty
                canGoForward = !changed.forward.isEmpty
            case .pageThemeChanged(let theme):
                observer(
                    .themeColorChanged(
                        theme.color.map {
                            NSColor(srgbRed: $0.red, green: $0.green, blue: $0.blue, alpha: $0.alpha)
                        }))
            case .pageInteracted: observer(.userActivity)
            case .linkHovered(let hovered): observer(.linkHovered(hovered.url.flatMap(URL.init(string:))))
            case .popupBlocked(let blocked):
                if let url = URL(string: blocked.pageURL) { observer(.popupBlocked(pageURL: url)) }
            case .contentFullscreenChanged(let fullscreen): observer(.contentFullscreenChanged(fullscreen.active))
            case .infoBarShown(let shown):
                guard
                    let bar = BrowserEngineInfoBar(
                        id: Int(shown.infoBarID), message: shown.message, acceptTitle: shown.acceptLabel ?? "",
                        cancelTitle: shown.cancelLabel ?? "", isCloseable: shown.closeable)
                else { return }
                observer(.infoBarAdded(bar))
            case .infoBarRemoved(let removed): observer(.infoBarRemoved(id: Int(removed.infoBarID)))
            case .mediaSessionChanged(let session):
                if let event = BrowserMediaSessionPageEvent(session) { observer(.mediaSession(event)) }
            case .contentMessagePosted(let message): receive(message)
            case .contentScriptEvaluated(let evaluated):
                evaluations.removeValue(forKey: evaluated.evaluationID)?.resume(returning: evaluated.json)
            case .storeInstallRequested(let request): performStoreRequest(request.extensionID, removes: false)
            case .storeRemovalRequested(let request): performStoreRequest(request.extensionID, removes: true)
            case .stagedLinkUnavailable:
                // A stale link is never retried as a bare address, which would
                // lose the initiating frame's security and referrer.
                observer(.loadingChanged(false))
                observer(.progressChanged(1))
            case .inspectorLayoutChanged: refreshDevTools()
            case .inspectorClosed: developerPanelDidClose()
            case .extensionsChanged, .sidePanelRequested, .profilePrepared, .profileReleased, .pageOffered:
                break
            case .findFinished:
                // The page's shared direct path hears its finds.
                break
            case .pageCaptured(let captured): receive(captured)
            case .pageExported(let exported): receive(exported)
            }
        }

        /// A script dialog the core asks the person, answered once they answer it.
        func ask(_ asked: ScriptDialogAsked, dismissal: BrowserPromptDismissal) {
            guard let promptPresenter else {
                engine?.answer(AnswerScriptDialog(promptID: asked.promptID, accepted: false, text: nil))
                return
            }
            promptPresenter.ask(asked, dismissal: dismissal)
        }

        /// A server's request for a user name and password. The credential goes
        /// to the core, which hands it to the engine and keeps no copy.
        func ask(_ asked: AuthenticationAsked, dismissal: BrowserPromptDismissal) {
            guard let promptPresenter else {
                engine?.answer(AnswerAuthentication(promptID: asked.promptID, credential: nil))
                return
            }
            promptPresenter.ask(asked, dismissal: dismissal)
        }

        /// A site's permission request its Space's choices do not answer. The
        /// core records an answer the person asks it to remember.
        func ask(_ asked: PermissionAsked, dismissal: BrowserPromptDismissal) {
            guard let promptPresenter else {
                engine?.answer(AnswerPermission(promptID: asked.promptID, grants: false, remembers: false))
                return
            }
            promptPresenter.ask(asked, dismissal: dismissal)
        }

        /// The engine created the page: the page's handlers and scripts go in,
        /// and its view goes on screen if it has a window to go in.
        private func viewReady() {
            guard !created else { return }
            created = true
            opening = false
            for script in contentScripts {
                pages?.request(
                    AddContentScript(pageID: pageID, source: script.source, mainFrameOnly: script.mainFrameOnly))
            }
            installHandlers()
            attachIfPossible()
        }

        private func creationFailed() {
            opening = false
            observer(.creationFailed(message: String(localized: "Chromium couldn’t create this page.")))
        }

        /// The handlers the Mac shell asks for what Chromium needs answered on
        /// its own stack. TRANSITIONAL until link questions travel as
        /// presentations (WP C (l)).
        private func installHandlers() {
            host?.setLinkHandler(page: pageID) { [weak self] action, address, label in
                MainActor.assumeIsolated {
                    guard let self, !self.disposed, let url = URL(string: address) else { return false }
                    return self.linkHandler(action, url, label)
                }
            }
            host?.setContextMenuHandler(
                page: pageID,
                provider: { [weak self] address, selection in
                    MainActor.assumeIsolated {
                        guard let self, !self.disposed else { return [] }
                        let url = address == "about:blank" ? nil : URL(string: address)
                        return self.contextMenuActions(url, selection.isEmpty ? nil : selection)
                    }
                },
                action: { [weak self] identifier, address, selection in
                    MainActor.assumeIsolated {
                        guard let self, !self.disposed else { return false }
                        let url = address == "about:blank" ? nil : URL(string: address)
                        return self.contextMenuAction(identifier, url, selection.isEmpty ? nil : selection)
                    }
                })
            host?.setProtectedLinkHandler(page: pageID) { [weak self] address in
                var deferred: CrestDeferredNavigation?
                MainActor.assumeIsolated {
                    guard let self, !self.disposed, let url = URL(string: address),
                        let action = self.protectedLinkHandler(url)
                    else { return }
                    deferred = { [weak self] in
                        MainActor.assumeIsolated {
                            guard let self, !self.disposed else { return }
                            action()
                        }
                    }
                }
                return deferred
            }
            host?.setModifiedLinkHandler(page: pageID) { [weak self] address, modifiers, token, reply in
                MainActor.assumeIsolated {
                    guard let self, !self.disposed, let url = URL(string: address) else {
                        reply(LinkNavigationDecision.navigate.name, nil)
                        return
                    }
                    let (decision, action) = self.modifiedLinkHandler(url, Int(modifiers), token)
                    var deferred: CrestDeferredNavigation?
                    if let action {
                        deferred = { [weak self] in
                            MainActor.assumeIsolated {
                                guard let self, !self.disposed else { return }
                                action()
                            }
                        }
                    }
                    reply(decision.name, deferred)
                }
            }
        }
    }

    extension ChromiumNativePage: BrowserPageDocumentServices {
        var documentServices: (any BrowserPageDocumentServices)? { self }
        var archiveFormat: BrowserPageArchiveFormat { .mhtml }

        func fullPageSnapshot(width: CGFloat?) async throws -> NSImage {
            let backingScale = surface.window?.backingScaleFactor ?? 1
            let data = try await exportData(format: .png, width: width ?? 0)
            guard let image = NSImage(data: data) else {
                throw BrowserPageExportError.renderingFailed("The page capture could not be decoded.")
            }
            // Chromium returns device pixels; AppKit composes the capture in points.
            let logicalWidth = width ?? image.size.width / backingScale
            image.size = NSSize(width: logicalWidth, height: image.size.height * logicalWidth / image.size.width)
            return image
        }

        func pdfData() async throws -> Data { try await exportData(format: .pdf) }
        func webArchiveData() async throws -> Data { try await exportData(format: .mhtml) }

        func printOperation(with info: NSPrintInfo) async throws -> NSPrintOperation {
            let data = try await pdfData()
            guard let document = PDFDocument(data: data),
                let operation = document.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true)
            else {
                throw BrowserPageExportError.renderingFailed("The page could not be prepared for printing.")
            }
            return operation
        }

        private func exportData(format: PageExportFormat, width: CGFloat = 0) async throws -> Data {
            guard created, let pages else { throw BrowserPageExportError.pageUnavailable }
            let exportID = UUID()
            return try await withCheckedThrowingContinuation { continuation in
                guard pages.request(ExportPage(pageID: pageID, exportID: exportID, format: format, width: width)) else {
                    continuation.resume(throwing: BrowserPageExportError.pageUnavailable)
                    return
                }
                exports[exportID] = continuation
            }
        }

        /// The export the engine made for this page, or why there is none.
        func receive(_ exported: PageExported) {
            guard let continuation = exports.removeValue(forKey: exported.exportID) else { return }
            if let document = exported.document {
                continuation.resume(returning: document)
            } else {
                let failure = exported.failure ?? PageExportFailure.failed
                continuation.resume(
                    throwing: BrowserPageExportError.renderingFailed(String(localized: failure.message)))
            }
        }
    }

    @MainActor
    final class ChromiumNativePageView: NSView, BrowserNativePageSurfaceLifecycle {
        weak var page: ChromiumNativePage?
        /// The docked DevTools frontend, while one is offered for this page. It is
        /// kept below the engine's page view so the page is drawn on top of it,
        /// which is the arrangement the resizing strategy is expressed in.
        var devToolsView: NSView? {
            didSet {
                guard devToolsView !== oldValue else { return }
                oldValue?.removeFromSuperview()
                guard let devToolsView else { return }
                devToolsView.autoresizingMask = []
                if let engineView {
                    addSubview(devToolsView, positioned: .below, relativeTo: engineView)
                } else {
                    addSubview(devToolsView)
                }
            }
        }
        /// The engine's page view. The DevTools frontend is a sibling, so the page
        /// is whichever subview is not it.
        private var engineView: NSView? {
            subviews.first { $0 !== devToolsView }
        }
        override func layout() {
            super.layout()
            layoutEngineView()
        }
        override func resizeSubviews(withOldSize oldSize: NSSize) {
            layoutEngineView()
        }
        func layoutEngineView() {
            guard !bounds.isEmpty, let view = engineView else { return }
            guard let devToolsView, let layout = page?.layoutInspector(in: bounds.size),
                let frontendFrame = layout.inspector.map({ frame(of: $0) }),
                let pageFrame = layout.page.map({ frame(of: $0) })
            else {
                view.isHidden = false
                view.frame = bounds
                // A navigation can replace Chromium's renderer after this container
                // was laid out. Propagate the viewport even when its size is unchanged.
                view.setFrameSize(bounds.size)
                return
            }
            devToolsView.frame = frontendFrame
            devToolsView.setFrameSize(frontendFrame.size)
            // An empty page rectangle is the frontend asking to cover the page —
            // its own device-toolbar and drawer layouts do this — so the page is
            // hidden rather than squeezed to nothing.
            view.isHidden = pageFrame.isEmpty
            guard !pageFrame.isEmpty else { return }
            view.frame = pageFrame
            view.setFrameSize(pageFrame.size)
        }

        /// An area the binding measured from the card's top left, as AppKit
        /// measures it, from the bottom left.
        private func frame(of area: PageArea) -> CGRect {
            CGRect(
                x: bounds.minX + area.x, y: bounds.minY + bounds.height - area.y - area.height,
                width: area.width, height: area.height)
        }
        override var acceptsFirstResponder: Bool { true }
        override func becomeFirstResponder() -> Bool {
            // The page, never the docked inspector beside it: focus arriving at the
            // card belongs to the page the card is showing.
            guard let view = engineView else { return super.becomeFirstResponder() }
            return window?.makeFirstResponder(view) ?? false
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { page?.attachIfPossible() } else { page?.detach() }
        }
        func didAttach(to host: BrowserWebHostView) { page?.attachIfPossible() }
        func willDetach(from host: BrowserWebHostView) { page?.detach() }
        func presentationGeometryDidChange() { layoutEngineView() }
    }
    extension ChromiumNativePage: BrowserPageContentScripting {
        func install(_ script: BrowserContentScript, receive: @escaping @MainActor (BrowserContentMessage) -> Void)
            -> Bool
        {
            guard !disposed else { return false }
            contentScripts.append(script)
            contentReceivers[script.handlerName] = receive
            if created, let pages {
                return pages.request(
                    AddContentScript(pageID: pageID, source: script.source, mainFrameOnly: script.mainFrameOnly))
            }
            return true
        }

        func callAsyncJavaScriptInMainFrame(_ body: String) async -> Any? {
            await evaluate(body, in: "main")
        }

        func callAsyncJavaScript(_ body: String, arguments: [String: Any], in frame: BrowserContentFrame) async throws
            -> Any?
        {
            guard created, !disposed, let frameID = frame.handle as? String else { return nil }
            // The arguments arrive as constants named for their keys, as WebKit's
            // callAsyncJavaScript binds them.
            var source = ""
            if !arguments.isEmpty {
                let json = String(decoding: try JSONSerialization.data(withJSONObject: arguments), as: UTF8.self)
                source = "const __crestArguments = \(json);\n"
                for key in arguments.keys.sorted() { source += "const \(key) = __crestArguments[\"\(key)\"];\n" }
            }
            source += body
            return await evaluate(source, in: frameID)
        }

        /// Runs `source` in the document `frameID` names and answers the value of
        /// its result, or nil when the document is gone.
        private func evaluate(_ source: String, in frameID: String) async -> Any? {
            guard created, let pages else { return nil }
            let evaluationID = UUID()
            let result: String? = await withCheckedContinuation { continuation in
                guard
                    pages.request(
                        EvaluateContentScript(
                            pageID: pageID, evaluationID: evaluationID, source: source, frameID: frameID))
                else {
                    continuation.resume(returning: nil)
                    return
                }
                evaluations[evaluationID] = continuation
            }
            guard let data = result?.data(using: .utf8),
                let value = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
                !(value is NSNull)
            else { return nil }
            return value
        }
    }
    extension ChromiumNativePage: BrowserMediaSessionTransport {
        func activateMediaSession(documentIdentifier: String) {
            guard created else { return }
            pages?.request(ActivateMediaSession(pageID: pageID, document: documentIdentifier))
        }

        func performMediaSessionAction(_ action: BrowserMediaSessionAction, documentIdentifier: String) {
            guard created else { return }
            pages?.request(
                PerformMediaAction(pageID: pageID, document: documentIdentifier, action: MediaSessionAction(action)))
        }

        func setMediaSessionMuted(_ muted: Bool, documentIdentifier: String) {
            guard created else { return }
            pages?.request(MuteMediaSession(pageID: pageID, document: documentIdentifier, muted: muted))
        }
    }

    extension MediaSessionAction {
        fileprivate init(_ action: BrowserMediaSessionAction) {
            switch action {
            case .play: self = .play
            case .pause: self = .pause
            case .previousTrack: self = .previousTrack
            case .nextTrack: self = .nextTrack
            }
        }
    }

    extension BrowserMediaSessionAction {
        fileprivate init(_ action: MediaSessionAction) {
            switch action {
            case .play: self = .play
            case .pause: self = .pause
            case .previousTrack: self = .previousTrack
            case .nextTrack: self = .nextTrack
            }
        }
    }

    extension BrowserMediaSessionPageEvent {
        /// The session the binding presented, as Crest's media store takes it,
        /// within the bounds a page script's report is held to.
        fileprivate init?(_ session: MediaSessionChanged) {
            typealias Bounds = BrowserMediaSessionPageEventDecoder
            guard !session.document.isEmpty, session.document.count <= Bounds.maximumDocumentIdentifierLength,
                session.location.count <= Bounds.maximumLocationLength
            else { return nil }
            func bounded(_ text: String?) -> String? {
                guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
                    trimmed.count <= Bounds.maximumTextLength
                else { return nil }
                return trimmed
            }
            let playback: BrowserMediaSessionPlaybackState
            switch session.playback {
            case .none: playback = .none
            case .playing: playback = .playing
            case .paused: playback = .paused
            }
            self.init(
                documentIdentifier: session.document, sequence: UInt64(max(session.sequence, 0)),
                location: session.location, isInvalidated: false, hasActiveSession: session.active,
                title: bounded(session.title), artist: bounded(session.artist), album: bounded(session.album),
                artworkData: nil,
                playbackState: playback, isAudible: session.audible, isMuted: session.muted,
                availableActions: Set(session.actions.map(BrowserMediaSessionAction.init)))
        }
    }

#endif
