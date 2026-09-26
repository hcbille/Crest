import Foundation
import WebKit

/// WebKit's binding, on the Mac and on iPhone and iPad. It builds each page
/// the core asks WebKit to create: the page's configuration for its profile,
/// with the platform's own settings, and the platform's web view, which the
/// page's owner then hosts. It loads an address through the owner's own load,
/// which prepares the page for it. The owner tears the web view down when it
/// releases the page, so closing only tells the core the page is gone. The
/// questions a page's document asks go to the core, which the page's host
/// shows the person, and come back as the core settles them. The files its
/// pages download run as WebKit's own downloads, which it reports to the core.
/// It erases what WebKit keeps for a profile when the core asks, whether or
/// not any page of it opened this run.
/// TRANSITIONAL until WP C (j1): a page the core unloads hands it no restore
/// state; its owner archives WebKit's state from the live web view instead.
@MainActor
final class WebKitEngineBinding: EngineBinding {
    // MARK: - Types

    private struct WeakPage {
        weak var value: WebKitEnginePage?
    }

    private struct WeakStore {
        weak var value: WKWebsiteDataStore?
    }

    /// A question one of this binding's pages raised with the core, until the
    /// core settles it.
    private enum PendingPrompt {
        case scriptDialog(pageID: UUID, answer: @MainActor (Bool, String?) -> Void)
        case authentication(pageID: UUID, answer: @MainActor (AuthenticationCredential?) -> Void)
        case permission(pageID: UUID, answer: @MainActor (Bool) -> Void)

        var pageID: UUID {
            switch self {
            case .scriptDialog(let pageID, _), .authentication(let pageID, _), .permission(let pageID, _): pageID
            }
        }

        /// Answers WebKit as nobody accepting or giving anything.
        @MainActor func decline() {
            switch self {
            case .scriptDialog(_, let answer): answer(false, nil)
            case .authentication(_, let answer): answer(nil)
            case .permission(_, let answer): answer(false)
            }
        }

        /// The answer that declines the prompt `promptID` through the core.
        func declining(_ promptID: UUID) -> any PromptIntent {
            switch self {
            case .scriptDialog: AnswerScriptDialog(promptID: promptID, accepted: false, text: nil)
            case .authentication: AnswerAuthentication(promptID: promptID, credential: nil)
            case .permission: AnswerPermission(promptID: promptID, grants: false, remembers: false)
            }
        }
    }

    // MARK: - Variables

    let integration = BrowserEngineRegistration.webKit
    private weak var engines: Engines?
    /// Removes a profile's stores, which WebKit keeps on disk across runs.
    private let profileStores: any BrowserEngineProfileRemoving
    /// The store each profile's pages use, while one holds it, which a site's
    /// data is cleared from.
    private var liveStores: [UUID: WeakStore] = [:]
    /// The files this binding's pages download, which the core records.
    private(set) lazy var downloads = WebKitDownloads(binding: self)
    /// The pages' direct path to the views this binding built.
    private(set) lazy var enginePages = WebKitEnginePages(binding: self)
    /// The pages this binding built, while their owners keep them.
    private var pages: [UUID: WeakPage] = [:]
    /// The questions this binding's pages raised, by prompt, until the core
    /// settles them.
    private var prompts: [UUID: PendingPrompt] = [:]
    /// How to close what each page's host shows for a question, until the
    /// question no longer waits.
    private var dismissals: [UUID: BrowserPromptDismissal] = [:]

    // MARK: - Initializers

    /// A binding whose profiles' stores `profileStores` removes.
    init(profileStores: any BrowserEngineProfileRemoving = WebKitBrowserWebsiteDataStoreRemover()) {
        self.profileStores = profileStores
    }

    // MARK: - Actions - Binding

    func attach(to engines: Engines) {
        self.engines = engines
        engines.core.followPrompts(self) { [weak self] change in self?.ask(change) }
    }

    func run(_ command: EngineCommand) {
        guard let engines else { return }
        switch command {
        case .createPage(let creation):
            if let request = engines.request(creation.pageID) {
                request.built = keep(build(creation, from: request.webKit))
            } else if let moving = engines.page(creation.pageID), let inputs = moving.webKitInputs?() {
                // The core moved a page the platform already hosts to WebKit:
                // its owner takes the new page before the core loads it.
                engines.handOver(keep(build(creation, from: inputs)), movedPage: moving)
            } else {
                engines.report(PageCreationFailed(pageID: creation.pageID), from: self)
                return
            }
            engines.report(PageCreated(pageID: creation.pageID), from: self)
        case .loadPage(let loading):
            guard let url = URL(string: loading.url) else { return }
            (engines.page(loading.pageID) ?? engines.request(loading.pageID)?.page)?.appLoad?(url)
        case .closePage(let closing):
            pages[closing.pageID] = nil
            // WebKit requires an answer to every question it asked.
            declinePrompts(of: closing.pageID)
            engines.report(PageClosed(pageID: closing.pageID, restoreState: nil), from: self)
        case .checkBeforeUnload(let check):
            prepareToClose(check.pageID)
        case .recoverPage(let recovery):
            // WebKit starts a new web content process for the page's current
            // history entry.
            pages[recovery.pageID]?.value?.webView.reload()
        case .settleScriptDialog(let settlement):
            guard case .scriptDialog(_, let answer)? = prompts.removeValue(forKey: settlement.promptID) else { return }
            answer(settlement.accepted, settlement.text)
        case .settleAuthentication(let settlement):
            guard case .authentication(_, let answer)? = prompts.removeValue(forKey: settlement.promptID) else { return }
            answer(settlement.credential)
        case .settlePermission(let settlement):
            guard case .permission(_, let answer)? = prompts.removeValue(forKey: settlement.promptID) else { return }
            answer(settlement.grants)
        case .settleDownloadDestination(let settlement):
            downloads.settle(settlement)
        case .cancelEngineDownload(let cancellation):
            downloads.cancel(cancellation.downloadID)
        case .removeEngineDownload(let removal):
            downloads.remove(removal.downloadID)
        case .approveEngineDownload(let approval):
            // WebKit warns about nothing itself, so the only download the core
            // approves is a blocked one the person retried.
            downloads.approve(approval.downloadID)
        case .eraseProfileData(let erasing):
            erase(erasing)
        case .eraseSiteData(let erasing):
            erase(erasing)
        case .settleExtensionInstall:
            // WebKit has no extensions, so the core never asks it to.
            break
        }
    }

    /// The core this binding reports to, while it is attached.
    var core: CrestCore? { engines?.core }

    /// The page this binding built as `pageID`, while its owner keeps it.
    func page(_ pageID: UUID) -> WebKitEnginePage? {
        pages[pageID]?.value
    }

    /// Reports what one of this binding's pages or downloads did.
    func report(_ event: some EngineEvent) {
        engines?.report(event, from: self)
    }

    // MARK: - Actions - Pages

    /// Keeps `page` as the binding's own, which its questions and its direct
    /// path reach while its owner keeps it.
    private func keep(_ page: WebKitEnginePage) -> WebKitEnginePage {
        page.binding = self
        pages = pages.filter { $0.value.value != nil }
        pages[page.id] = WeakPage(value: page)
        return page
    }

    /// The page for `creation`, with the configuration `inputs` hands over, or
    /// one assembled for the page's profile with the platform's own settings.
    private func build(_ creation: CreatePage, from inputs: WebKitPageInputs) -> WebKitEnginePage {
        let configuration =
            inputs.configuration
            ?? BrowserPageConfiguration.make(
                for: BrowsingProfile(id: creation.profileID),
                websiteDataStore: inputs.websiteDataStore,
                contentRuleLists: inputs.contentRuleLists,
                preferredContentMode: BrowserPlatformWebKit.preferredContentMode,
                decorate: BrowserPlatformWebKit.decorate)
        liveStores = liveStores.filter { $0.value.value != nil }
        liveStores[creation.profileID] = WeakStore(value: configuration.websiteDataStore)
        return WebKitEnginePage(
            id: creation.pageID,
            profileID: creation.profileID,
            webView: BrowserPlatformWebKit.makeWebView(configuration: configuration),
            contentRuleLists: inputs.contentRuleLists,
            ownsUserContentController: !inputs.sharesUserContentController)
    }

    // MARK: - Actions - Data

    /// Erases every store WebKit keeps for the profile; one that keeps
    /// nothing on disk has nothing to erase.
    private func erase(_ erasing: EraseProfileData) {
        // An ephemeral profile keeps nothing on disk: its stores went with the
        // pages that held them.
        guard !erasing.ephemeral else {
            report(DataErased(erasureID: erasing.erasureID, erased: true))
            return
        }
        let stores = profileStores
        Task { [weak self] in
            let erased: Bool
            do {
                try await stores.removeProfile(BrowsingProfile(id: erasing.profileID), ephemeral: erasing.ephemeral)
                erased = true
            } catch {
                erased = false
            }
            self?.report(DataErased(erasureID: erasing.erasureID, erased: erased))
        }
    }

    /// Clears the site from the store the profile's pages use, or from its
    /// store on disk, without creating one the profile does not have.
    private func erase(_ erasing: EraseSiteData) {
        let live = liveStores[erasing.profileID]?.value
        Task { [weak self] in
            guard let site = URL(string: "https://\(erasing.host)/") else {
                self?.report(DataErased(erasureID: erasing.erasureID, erased: false))
                return
            }
            let onDisk = erasing.ephemeral || live != nil ? nil : await Self.storeOnDisk(for: erasing.profileID)
            if let store = live ?? onDisk { await BrowserWebsiteDataStore.clearSiteData(for: site, in: store) }
            self?.report(DataErased(erasureID: erasing.erasureID, erased: true))
        }
    }

    /// The profile's store on disk, when it has one.
    private static func storeOnDisk(for profileID: UUID) async -> WKWebsiteDataStore? {
        let identifier = BrowserLaunchEnvironment.current.websiteDataStoreIdentifier(forProfileID: profileID)
        guard await WKWebsiteDataStore.allDataStoreIdentifiers.contains(identifier) else { return nil }
        return WKWebsiteDataStore(forIdentifier: identifier)
    }

    // MARK: - Actions - Prompts

    /// Raises with the core a script dialog the document of page `pageID`
    /// opened. The core settles it with the person's answer, or declines it
    /// when nobody can give one.
    func raise(_ question: ScriptDialogQuestion, for pageID: UUID, answer: @escaping @MainActor (Bool, String?) -> Void) {
        guard let engines else { return answer(false, nil) }
        let promptID = UUID()
        prompts[promptID] = .scriptDialog(pageID: pageID, answer: answer)
        engines.report(ScriptDialogOpened(promptID: promptID, pageID: pageID, question: question), from: self)
    }

    /// Raises with the core a server's request for a user name and password
    /// a load of page `pageID` met. The core settles it with the credential
    /// to answer with, or declines it.
    func raise(
        _ question: AuthenticationQuestion, for pageID: UUID,
        answer: @escaping @MainActor (AuthenticationCredential?) -> Void
    ) {
        guard let engines else { return answer(nil) }
        let promptID = UUID()
        prompts[promptID] = .authentication(pageID: pageID, answer: answer)
        engines.report(AuthenticationChallenged(promptID: promptID, pageID: pageID, question: question), from: self)
    }

    /// Raises with the core, as `promptID`, a site's request in page `pageID`
    /// for a capability. The core answers it from the Space's choices, or
    /// settles it with the person's answer.
    func raise(
        _ question: PermissionQuestion, for pageID: UUID, promptID: UUID = UUID(),
        answer: @escaping @MainActor (Bool) -> Void
    ) {
        guard let engines else { return answer(false) }
        prompts[promptID] = .permission(pageID: pageID, answer: answer)
        engines.report(PermissionRequested(promptID: promptID, pageID: pageID, question: question), from: self)
    }

    /// Takes back a question a page no longer asks: WebKit hears it declined,
    /// and the core stops waiting for it and records nothing.
    func withdraw(_ promptID: UUID) {
        guard let prompt = prompts.removeValue(forKey: promptID) else { return }
        prompt.decline()
        engines?.report(PromptWithdrawn(promptID: promptID), from: self)
    }

    /// Shows a question the core asks about one of this binding's pages on
    /// the page's host, and closes it once the core settles it. One no host
    /// can show is declined.
    private func ask(_ change: Change) {
        switch change {
        case .scriptDialogAsked(let asked):
            present(asked.promptID, on: asked.pageID) { $0.ask(asked, dismissal: $1) }
        case .authenticationAsked(let asked):
            present(asked.promptID, on: asked.pageID) { $0.ask(asked, dismissal: $1) }
        case .permissionAsked(let asked):
            present(asked.promptID, on: asked.pageID) { $0.ask(asked, dismissal: $1) }
        case .promptSettled(let settled):
            dismissals.removeValue(forKey: settled.promptID)?.dismiss()
        default:
            break
        }
    }

    /// Shows one of this binding's prompts with `show` on the host of page
    /// `pageID`, or declines it when no host can show it.
    private func present(
        _ promptID: UUID, on pageID: UUID, _ show: (any BrowserPromptPresenting, BrowserPromptDismissal) -> Void
    ) {
        guard let prompt = prompts[promptID] else { return }
        guard let presenter = pages[pageID]?.value?.presenter else {
            _ = try? engines?.core.send(prompt.declining(promptID))
            return
        }
        show(presenter, dismissal(for: promptID))
    }

    /// A new dismissal for a question a page's host shows.
    private func dismissal(for promptID: UUID) -> BrowserPromptDismissal {
        let dismissal = BrowserPromptDismissal()
        dismissals[promptID] = dismissal
        return dismissal
    }

    /// Declines what page `pageID` still asks, which closes with it.
    private func declinePrompts(of pageID: UUID) {
        for (promptID, prompt) in prompts where prompt.pageID == pageID {
            prompts[promptID] = nil
            prompt.decline()
        }
    }

    /// Asks the page's beforeunload handlers whether it may close, where
    /// WebKit runs them for an embedder close; any other page may go.
    private func prepareToClose(_ pageID: UUID) {
        #if os(macOS)
            if let page = pages[pageID]?.value {
                page.engine.prepareToClose { [weak self] proceeds in
                    guard let self else { return }
                    self.engines?.report(BeforeUnloadAnswered(pageID: pageID, proceeds: proceeds), from: self)
                }
                return
            }
        #endif
        engines?.report(BeforeUnloadAnswered(pageID: pageID, proceeds: true), from: self)
    }
}
