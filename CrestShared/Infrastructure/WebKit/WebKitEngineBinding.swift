import Foundation
import WebKit

/// WebKit's binding, on the Mac and on iPhone and iPad. It builds each page
/// the core asks WebKit to create: the page's configuration for its profile,
/// with the platform's own settings, and the platform's web view, which the
/// page's owner then hosts. It loads an address through the owner's own load,
/// which prepares the page for it. The owner tears the web view down when it
/// releases the page, so closing only tells the core the page is gone. The
/// questions a page's document asks go to the core, which the page's host
/// shows the person, and come back as the core settles them.
/// TRANSITIONAL until WP C (j1): a page the core unloads hands it no restore
/// state; its owner archives WebKit's state from the live web view instead.
@MainActor
final class WebKitEngineBinding: EngineBinding {
    // MARK: - Types

    private struct WeakPage {
        weak var value: WebKitEnginePage?
    }

    /// A question one of this binding's pages raised with the core, until the
    /// core settles it.
    private enum PendingPrompt {
        case scriptDialog(pageID: UUID, answer: @MainActor (Bool, String?) -> Void)
        case authentication(pageID: UUID, answer: @MainActor (AuthenticationCredential?) -> Void)

        var pageID: UUID {
            switch self {
            case .scriptDialog(let pageID, _), .authentication(let pageID, _): pageID
            }
        }

        /// Answers WebKit as nobody accepting or giving anything.
        @MainActor func decline() {
            switch self {
            case .scriptDialog(_, let answer): answer(false, nil)
            case .authentication(_, let answer): answer(nil)
            }
        }

        /// The answer that declines the prompt `promptID` through the core.
        func declining(_ promptID: UUID) -> any PromptIntent {
            switch self {
            case .scriptDialog: AnswerScriptDialog(promptID: promptID, accepted: false, text: nil)
            case .authentication: AnswerAuthentication(promptID: promptID, credential: nil)
            }
        }
    }

    // MARK: - Variables

    let integration = BrowserEngineRegistration.webKit
    private weak var engines: Engines?
    /// The pages this binding built, while their owners keep them.
    private var pages: [UUID: WeakPage] = [:]
    /// The questions this binding's pages raised, by prompt, until the core
    /// settles them.
    private var prompts: [UUID: PendingPrompt] = [:]
    /// How to close what each page's host shows for a question, until the
    /// question no longer waits.
    private var dismissals: [UUID: BrowserPromptDismissal] = [:]

    // MARK: - Actions - Binding

    func attach(to engines: Engines) {
        self.engines = engines
        engines.core.followPrompts(self) { [weak self] change in self?.ask(change) }
    }

    func run(_ command: EngineCommand) {
        guard let engines else { return }
        switch command {
        case .createPage(let creation):
            guard let request = engines.request(creation.pageID) else {
                engines.report(PageCreationFailed(pageID: creation.pageID), from: self)
                return
            }
            let page = build(creation, from: request.webKit)
            page.binding = self
            pages = pages.filter { $0.value.value != nil }
            pages[creation.pageID] = WeakPage(value: page)
            request.built = page
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
        case .settlePermission, .settleExtensionInstall, .settleDownloadDestination, .cancelEngineDownload,
            .removeEngineDownload, .approveEngineDownload:
            // WebKit answers its own permission requests and runs its own
            // downloads until its binding reports them to the core (WP C
            // (j1)), so the core never asks it to.
            break
        }
    }

    // MARK: - Actions - Pages

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
        return WebKitEnginePage(
            id: creation.pageID,
            webView: BrowserPlatformWebKit.makeWebView(configuration: configuration),
            contentRuleLists: inputs.contentRuleLists,
            ownsUserContentController: !inputs.sharesUserContentController)
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

    /// Shows a question the core asks about one of this binding's pages on
    /// the page's host, and closes it once the core settles it. One no host
    /// can show is declined.
    private func ask(_ change: Change) {
        switch change {
        case .scriptDialogAsked(let asked):
            present(asked.promptID, on: asked.pageID) { $0.ask(asked, dismissal: $1) }
        case .authenticationAsked(let asked):
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
