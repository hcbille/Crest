#if CREST_CHROMIUM_HOST
    import CrestCoreABI
    import Foundation

    /// Chromium, the default engine. Its binding is the engine's own C++: the
    /// core hands it commands through the binding's function table, and the
    /// binding creates, loads and closes each page and reports what it does
    /// straight to the core. This hosts the pages' views, and its pages ask
    /// the binding for their view work directly.
    @MainActor
    final class ChromiumEngine: NativeEngineBinding {
        // MARK: - Variables

        let integration = BrowserEngineRegistration.chromium
        let table: crest_engine_binding_t
        let fingerprint: [UInt8]
        /// The browser operations a page may ask for, such as the Space a
        /// Chrome Web Store listing installs into. Weak: the composition owns it.
        weak var hostCommands: (any BrowserEngineHostCommands)?
        /// The Mac shell, for what only AppKit does.
        let host: any CrestMacShell
        /// The pages' direct path to the binding, which hears the binding's
        /// presentations from the engine's start on.
        private(set) var pages: NativeEnginePages!
        /// The core that asks this engine's questions of the person and hears
        /// the answers. Weak: the composition owns it.
        private weak var core: CrestCore?
        /// What closes each question a page shows, until the core settles it.
        private var dismissals: [UUID: BrowserPromptDismissal] = [:]
        /// Each page this hosts, while its owner keeps it.
        private var hosted: [UUID: WeakNativePage] = [:]
        /// What waits for the binding to prepare each profile, by the
        /// preparation's identity.
        private var preparations: [UUID: CheckedContinuation<Bool, Never>] = [:]

        // MARK: - Initializers

        init(
            host: any CrestMacShell, table: crest_engine_binding_t, fingerprint: [UInt8],
            pages: crest_engine_pages_t
        ) {
            self.host = host
            self.table = table
            self.fingerprint = fingerprint
            self.pages = NativeEnginePages(table: pages) { [weak self] presentation in self?.present(presentation) }
        }

        // MARK: - Actions - Pages

        func host(_ page: CorePage) -> AnyObject {
            let native = ChromiumNativePage(id: page.id, engine: self)
            hold(native)
            return ChromiumPageAdapter(native)
        }

        // MARK: - Actions - Prompts

        /// Hears the questions `core` asks the person, which this engine's
        /// pages show. Its downloads' questions are the app's to answer.
        func follow(_ core: CrestCore) {
            self.core = core
            core.followChanges(self)
        }

        /// Sends the person's answer to a question the core asked.
        func answer(_ intent: some PromptIntent) {
            _ = try? core?.send(intent)
        }

        /// Whether the core hosts `pageID` on another engine.
        private func isAnotherEnginesPage(_ pageID: UUID) -> Bool {
            guard let engine = core?.state.pages[pageID]?.engine else { return false }
            return engine != .chromium
        }

        /// A new dismissal for a question a page shows.
        private func dismissal(for promptID: UUID) -> BrowserPromptDismissal {
            let dismissal = BrowserPromptDismissal()
            dismissals[promptID] = dismissal
            return dismissal
        }

        // MARK: - Actions - Links

        /// The app's own load of `url` in `pageID`, which the core resolves by
        /// the page's Space and asks the binding to run.
        func navigate(_ pageID: UUID, to url: URL) {
            _ = try? core?.send(Navigate(pageID: pageID, input: url.absoluteString))
        }

        /// Makes the link the binding staged as `stagedLinkID` in `sourcePageID`
        /// the first load of `pageID`, when it loads `url`. False when the core
        /// refuses it, such as for pages of another engine or profile.
        func stage(_ stagedLinkID: UUID, from sourcePageID: UUID, into pageID: UUID, expecting url: URL) -> Bool {
            guard let core else { return false }
            do {
                try core.send(
                    StageLink(
                        pageID: pageID, sourcePageID: sourcePageID, stagedLinkID: stagedLinkID,
                        url: url.absoluteString))
                return true
            } catch {
                return false
            }
        }

        // MARK: - Actions - Profiles

        /// Loads a Space's profile so its extensions can be listed before anything
        /// opens in it; answers whether it is ready.
        func prepareProfile(_ profileID: UUID) async -> Bool {
            let preparationID = UUID()
            return await withCheckedContinuation { continuation in
                guard pages.request(PrepareProfile(profileID: profileID, preparationID: preparationID)) else {
                    continuation.resume(returning: false)
                    return
                }
                preparations[preparationID] = continuation
            }
        }

        func icon(of pageID: UUID) -> Data? {
            pages.request(PageIcon(pageID: pageID)).image
        }

        /// The live page the engine names with `id`, for requests that arrive
        /// with only a page identifier, such as a side panel's.
        func page(_ id: String) -> ChromiumNativePage? {
            UUID(uuidString: id).flatMap { hosted[$0]?.page }
        }

        /// The live page the core names `pageID`, for what the Mac shell asks
        /// of it, such as its context menu's rows.
        func page(_ pageID: UUID) -> ChromiumNativePage? {
            hosted[pageID]?.page
        }

        private func hold(_ native: ChromiumNativePage) {
            hosted = hosted.filter { $0.value.page != nil }
            hosted[native.pageID] = WeakNativePage(page: native)
        }

        /// Hands a presentation to what it is about: the extensions, a profile
        /// or a side panel here, and one about a page to that page. One for a
        /// page that is gone changes nothing.
        private func present(_ presentation: EnginePresentation) {
            presentation.dispatch(to: self)
            guard let pageID = presentation.pageID else { return }
            hosted[pageID]?.page?.receive(presentation)
        }
    }

    // MARK: - Prompts

    /// Shows a question the core asks on the page that asked it, and closes it
    /// once the core settles it. One no page of this engine can show any more
    /// is declined; one about a page another engine hosts is that engine's to
    /// show. It observes only the questions Chromium's pages and extensions ask.
    extension ChromiumEngine: ChangeObserving {
        func handle(_ asked: ScriptDialogAsked) {
            guard let page = hosted[asked.pageID]?.page else {
                guard !isAnotherEnginesPage(asked.pageID) else { return }
                return answer(AnswerScriptDialog(promptID: asked.promptID, accepted: false, text: nil))
            }
            page.ask(asked, dismissal: dismissal(for: asked.promptID))
        }

        func handle(_ asked: AuthenticationAsked) {
            guard let page = hosted[asked.pageID]?.page else {
                guard !isAnotherEnginesPage(asked.pageID) else { return }
                return answer(AnswerAuthentication(promptID: asked.promptID, credential: nil))
            }
            page.ask(asked, dismissal: dismissal(for: asked.promptID))
        }

        func handle(_ asked: PermissionAsked) {
            guard let page = hosted[asked.pageID]?.page else {
                guard !isAnotherEnginesPage(asked.pageID) else { return }
                return answer(AnswerPermission(promptID: asked.promptID, grants: false, remembers: false))
            }
            page.ask(asked, dismissal: dismissal(for: asked.promptID))
        }

        func handle(_ asked: ExtensionInstallAsked) {
            CrestChromiumRoot.extensions.review(asked) { [weak self] accepted, withholds in
                self?.answer(
                    AnswerExtensionInstall(promptID: asked.promptID, accepted: accepted, withholdsSiteAccess: withholds)
                )
            }
        }

        func handle(_ settled: PromptSettled) {
            dismissals.removeValue(forKey: settled.promptID)?.dismiss()
        }
    }

    // MARK: - Presentations

    /// What the binding presents about the extensions, a profile or a side
    /// panel, which the engine handles itself; it observes only these, and
    /// hands what it presents about a page to that page.
    extension ChromiumEngine: EnginePresentationObserving {
        func handle(_ presentation: ExtensionsChanged) {
            CrestChromiumRoot.extensions.refresh()
        }

        func handle(_ prepared: ProfilePrepared) {
            preparations.removeValue(forKey: prepared.preparationID)?.resume(returning: prepared.ready)
        }

        func handle(_ released: ProfileReleased) {
            CrestChromiumRoot.profileReleased(released)
        }

        func handle(_ requested: SidePanelRequested) {
            CrestChromiumRoot.routeSidePanel(requested)
        }
    }

    /// A hosted page, held weakly so it goes with its owner.
    private struct WeakNativePage {
        weak var page: ChromiumNativePage?
    }

    /// The framework's entry point, which Chromium calls on its UI thread, the
    /// main thread, once it loads the framework: the Mac shell's host, the
    /// engine binding to register with the core the framework creates, and the
    /// pages' direct path to it. Public so a Release build, which hides
    /// internal symbols, still exports it for Chromium's lookup by name.
    @MainActor
    @_cdecl("crest_chromium_ui_start")
    public func crestChromiumUIStart(
        _ host: any CrestMacShell, _ binding: UnsafePointer<crest_engine_binding_t>,
        _ fingerprint: UnsafePointer<UInt8>, _ fingerprintLength: Int, _ pages: UnsafePointer<crest_engine_pages_t>
    ) {
        let contract = Array(UnsafeBufferPointer(start: fingerprint, count: fingerprintLength))
        host.attach(ui: ChromiumMacUI())
        CrestChromiumRoot.start(host: host, binding: binding.pointee, fingerprint: contract, pages: pages.pointee)
    }
#endif
