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
        let host: any CrestChromiumEngineHost
        /// The pages' direct path to the binding, which hears the binding's
        /// presentations from the engine's start on.
        private(set) var pages: NativeEnginePages!
        /// Shows the engine's downloads. Weak: the composition owns it.
        weak var downloads: ChromiumDownloadAdapter?
        /// Each page this hosts, while its owner keeps it.
        private var hosted: [UUID: WeakNativePage] = [:]
        /// What waits for the binding's profiles: each preparation and deletion by
        /// its identity.
        private var preparations: [UUID: CheckedContinuation<Bool, Never>] = [:]
        private var deletions: [UUID: CheckedContinuation<Bool, Never>] = [:]

        // MARK: - Initializers

        init(
            host: any CrestChromiumEngineHost, table: crest_engine_binding_t, fingerprint: [UInt8],
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
            case .engineDownloadChanged(let changed): downloads?.receive(changed.download)
            case .engineDownloadDestinationRequested(let request):
                if let downloads {
                    downloads.resolveDestination(request)
                } else {
                    pages.request(AnswerEngineDownloadDestination(requestID: request.requestID, path: nil))
                }
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
            case .extensionsChanged, .profilePrepared, .profileDeleted, .profileReleased, .pageOffered,
                .engineDownloadChanged, .engineDownloadDestinationRequested:
                nil
            case .contentFullscreenChanged(let value): value.pageID
            case .contentMessagePosted(let value): value.pageID
            case .contentScriptEvaluated(let value): value.pageID
            case .findFinished(let value): value.pageID
            case .infoBarRemoved(let value): value.pageID
            case .infoBarShown(let value): value.pageID
            case .authenticationRequested(let value): value.pageID
            case .javaScriptDialogRequested(let value): value.pageID
            case .permissionRequested(let value): value.pageID
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
        _ host: any CrestChromiumEngineHost, _ binding: UnsafePointer<crest_engine_binding_t>,
        _ fingerprint: UnsafePointer<UInt8>, _ fingerprintLength: Int, _ pages: UnsafePointer<crest_engine_pages_t>
    ) {
        let contract = Array(UnsafeBufferPointer(start: fingerprint, count: fingerprintLength))
        CrestChromiumRoot.start(host: host, binding: binding.pointee, fingerprint: contract, pages: pages.pointee)
    }
#endif
