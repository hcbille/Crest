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
        /// Shows the questions the engine asks for itself, such as keeping a
        /// download it warned about.
        private let dialogPresenter = BrowserDialogPresenter()
        /// The folder access each download writing into a chosen folder holds
        /// until it ends.
        private var downloadFolders: [UUID: URL] = [:]
        /// Each page this hosts, while its owner keeps it.
        private var hosted: [UUID: WeakNativePage] = [:]
        /// What waits for the binding's profiles: each preparation and deletion by
        /// its identity.
        private var preparations: [UUID: CheckedContinuation<Bool, Never>] = [:]
        private var deletions: [UUID: CheckedContinuation<Bool, Never>] = [:]

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

        /// One of the engine's own pages that Settings shows in `profileID`,
        /// which no tab owns and the core never hears of.
        func standalonePage(in profileID: UUID) -> ChromiumNativePage {
            let native = ChromiumNativePage(standaloneIn: profileID, engine: self)
            hold(native)
            return native
        }

        // MARK: - Actions - Prompts

        /// Hears the questions `core` asks the person, which this engine's
        /// pages show.
        func follow(_ core: CrestCore) {
            self.core = core
            core.followPrompts(self) { [weak self] change in self?.ask(change) }
            core.followDownloads(self) { [weak self] download in
                guard !download.phase.isLive else { return }
                self?.downloadFolders.removeValue(forKey: download.id)?.stopAccessingSecurityScopedResource()
            }
        }

        /// Sends the person's answer to a question the core asked.
        func answer(_ intent: some PromptIntent) {
            _ = try? core?.send(intent)
        }

        /// Shows a question the core asks on the page that asked it, and closes
        /// it once the core settles it. One no page of this engine can show any
        /// more is declined; one about a page another engine hosts is that
        /// engine's to show.
        private func ask(_ change: Change) {
            switch change {
            case .scriptDialogAsked(let asked):
                guard let page = hosted[asked.pageID]?.page else {
                    guard !isAnotherEnginesPage(asked.pageID) else { return }
                    return answer(AnswerScriptDialog(promptID: asked.promptID, accepted: false, text: nil))
                }
                page.ask(asked, dismissal: dismissal(for: asked.promptID))
            case .authenticationAsked(let asked):
                guard let page = hosted[asked.pageID]?.page else {
                    guard !isAnotherEnginesPage(asked.pageID) else { return }
                    return answer(AnswerAuthentication(promptID: asked.promptID, credential: nil))
                }
                page.ask(asked, dismissal: dismissal(for: asked.promptID))
            case .permissionAsked(let asked):
                guard let page = hosted[asked.pageID]?.page else {
                    guard !isAnotherEnginesPage(asked.pageID) else { return }
                    return answer(AnswerPermission(promptID: asked.promptID, grants: false, remembers: false))
                }
                page.ask(asked, dismissal: dismissal(for: asked.promptID))
            case .extensionInstallAsked(let asked):
                CrestChromiumRoot.extensions.review(asked) { [weak self] accepted, withholds in
                    self?.answer(
                        AnswerExtensionInstall(promptID: asked.promptID, accepted: accepted, withholdsSiteAccess: withholds))
                }
            case .downloadDestinationAsked(let asked): resolveDestination(asked)
            case .downloadApprovalAsked(let asked):
                let dismissal = dismissal(for: asked.promptID)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let approved = await dialogPresenter.approveEngineDownload(
                        filename: asked.filename, message: Self.message(for: asked.warning), dismissal: dismissal)
                    answer(AnswerDownloadApproval(promptID: asked.promptID, approved: approved))
                }
            case .promptSettled(let settled):
                dismissals.removeValue(forKey: settled.promptID)?.dismiss()
            default:
                break
            }
        }

        /// Whether the core hosts `pageID` on another engine.
        private func isAnotherEnginesPage(_ pageID: UUID) -> Bool {
            guard let engine = core?.state.pages[pageID]?.engine else { return false }
            return engine != .chromium
        }

        /// Where a download's file goes: the Space's download folder, or where
        /// the person chooses when the Space or the engine asks for that.
        private func resolveDestination(_ asked: DownloadDestinationAsked) {
            Task { @MainActor [weak self] in
                let resolution = await BrowserPlatformDownloadDirectory.resolve(
                    suggestedFilename: asked.suggestedFilename, spaceID: asked.spaceID, forcesPrompt: asked.forcesPrompt)
                guard let self else {
                    if case .destination(_, let scoped) = resolution { scoped?.stopAccessingSecurityScopedResource() }
                    return
                }
                switch resolution {
                case .destination(let url, let scoped):
                    if let scoped { downloadFolders[asked.downloadID] = scoped }
                    answer(AnswerDownloadDestination(promptID: asked.promptID, path: url.path))
                case .cancelled:
                    answer(AnswerDownloadDestination(promptID: asked.promptID, path: nil))
                case .unavailable:
                    _ = try? core?.send(
                        FailDownload(downloadID: asked.downloadID, reason: .folderUnavailable, message: nil))
                    answer(AnswerDownloadDestination(promptID: asked.promptID, path: nil))
                }
            }
        }

        /// What the person is told about a download the engine warned about.
        private static func message(for warning: EngineDownloadWarning) -> String {
            switch warning {
            case .insecureConnection:
                String(
                    localized:
                        "This file was transferred over an insecure connection and could have been changed by someone else. Keep it only if you trust its source."
                )
            case .dangerousFile:
                String(localized: "This type of file can change your computer. Keep it only if you trust its source.")
            case .uncommonContent:
                String(localized: "This file is not commonly downloaded. The engine could not confirm that it is safe.")
            case .potentiallyUnwanted:
                String(localized: "This file may change your browser or computer settings without your permission.")
            case .insecureBlocked:
                String(localized: "The engine blocked this insecure download.")
            case .policyBlocked:
                String(
                    localized:
                        "The engine blocked this download because of its safety or organization policy verdict.")
            }
        }

        /// A new dismissal for a question a page shows.
        private func dismissal(for promptID: UUID) -> BrowserPromptDismissal {
            let dismissal = BrowserPromptDismissal()
            dismissals[promptID] = dismissal
            return dismissal
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

        /// Deletes a Space's profile and its data; answers whether it is gone.
        func deleteProfile(_ profileID: UUID, ephemeral: Bool) async -> Bool {
            let deletionID = UUID()
            return await withCheckedContinuation { continuation in
                guard pages.request(DeleteProfile(profileID: profileID, ephemeral: ephemeral, deletionID: deletionID))
                else {
                    continuation.resume(returning: false)
                    return
                }
                deletions[deletionID] = continuation
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

        private func hold(_ native: ChromiumNativePage) {
            hosted = hosted.filter { $0.value.page != nil }
            hosted[native.pageID] = WeakNativePage(page: native)
        }

        /// Hands a presentation to the page it names; one for a page that is
        /// gone changes nothing.
        private func present(_ presentation: EnginePresentation) {
            switch presentation {
            case .extensionsChanged: CrestChromiumRoot.extensions.refresh()
            case .profilePrepared(let prepared):
                preparations.removeValue(forKey: prepared.preparationID)?.resume(returning: prepared.ready)
            case .profileDeleted(let deleted):
                deletions.removeValue(forKey: deleted.deletionID)?.resume(returning: deleted.deleted)
            case .profileReleased(let released): CrestChromiumRoot.profileReleased(released.profileID)
            case .pageOffered(let offer): CrestChromiumRoot.pageOffered(offer)
            case .sidePanelRequested(let requested): CrestChromiumRoot.routeSidePanel(requested)
            default:
                guard let pageID = presentation.pageID else { return }
                hosted[pageID]?.page?.receive(presentation)
            }
        }
    }

    extension EnginePresentation {
        /// The page the presentation is about, or none for a profile's.
        fileprivate var pageID: UUID? {
            switch self {
            case .extensionsChanged, .profilePrepared, .profileDeleted, .profileReleased, .pageOffered:
                nil
            case .contentFullscreenChanged(let value): value.pageID
            case .contentMessagePosted(let value): value.pageID
            case .contentScriptEvaluated(let value): value.pageID
            case .findFinished(let value): value.pageID
            case .infoBarRemoved(let value): value.pageID
            case .infoBarShown(let value): value.pageID
            case .siteDataCleared(let value): value.pageID
            case .sidePanelRequested(let value): value.pageID
            case .inspectorClosed(let value): value.pageID
            case .inspectorLayoutChanged(let value): value.pageID
            case .linkHovered(let value): value.pageID
            case .mediaSessionChanged(let value): value.pageID
            case .pageCaptured(let value): value.pageID
            case .pageExported(let value): value.pageID
            case .pageHistoryChanged(let value): value.pageID
            case .pageInteracted(let value): value.pageID
            case .pageLoadingChanged(let value): value.pageID
            case .pageNavigationCommitted(let value): value.pageID
            case .pageNavigationFailed(let value): value.pageID
            case .pageNavigationStarted(let value): value.pageID
            case .pageRendererGone(let value): value.pageID
            case .pageThemeChanged(let value): value.pageID
            case .pageViewClosed(let value): value.pageID
            case .pageViewReady(let value): value.pageID
            case .pageViewUnavailable(let value): value.pageID
            case .popupBlocked(let value): value.pageID
            case .stagedLinkUnavailable(let value): value.pageID
            case .storeInstallRequested(let value): value.pageID
            case .storeRemovalRequested(let value): value.pageID
            }
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
