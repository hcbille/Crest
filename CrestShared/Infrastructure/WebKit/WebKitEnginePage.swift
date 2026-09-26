import WebKit

/// A page WebKit's binding built for a page the core opened: its web view,
/// built for the page's profile with the platform's own settings, and WebKit's
/// page port over it. The page's owner hosts the web view and answers its
/// delegates until the binding does (WP C (j1)).
@MainActor
final class WebKitEnginePage {
    // MARK: - Variables

    /// The core's page this one is.
    let id: UUID
    /// The profile the page browses in, which its downloads belong to.
    let profileID: UUID
    let webView: WKWebView
    let engine: BrowserWebKitPageEngine
    /// The content rules the page was built with.
    let contentRuleLists: [WKContentRuleList]
    /// False when the page shares the user content controller of the page its
    /// configuration came from, which every popup does: WebKit copies the
    /// opener's configuration and the copy keeps the same controller.
    /// Installing the same script message handler twice on it throws, and
    /// removing one would strip it from the opener.
    let ownsUserContentController: Bool
    /// The platform's page hosting this one, which shows the person the
    /// core's questions about it.
    weak var presenter: (any BrowserPromptPresenting)?
    /// The binding that built the page, which raises its questions with the
    /// core.
    weak var binding: WebKitEngineBinding?

    // MARK: - Initializers

    init(
        id: UUID, profileID: UUID, webView: WKWebView, contentRuleLists: [WKContentRuleList],
        ownsUserContentController: Bool
    ) {
        self.id = id
        self.profileID = profileID
        self.webView = webView
        engine = BrowserWebKitPageEngine(webView: webView)
        self.contentRuleLists = contentRuleLists
        self.ownsUserContentController = ownsUserContentController
    }

    // MARK: - Actions - Prompts

    /// Asks the core the script dialog the page's document opened. `answer`
    /// runs once: with the person's answer, or declined when nobody can give
    /// one.
    func ask(_ question: ScriptDialogQuestion, answer: @escaping @MainActor (Bool, String?) -> Void) {
        guard let binding else { return answer(false, nil) }
        binding.raise(question, for: id, answer: answer)
    }

    /// Asks the core a server's request for a user name and password. `answer`
    /// runs once: with the credential to answer the server with, or nil.
    func ask(_ question: AuthenticationQuestion, answer: @escaping @MainActor (AuthenticationCredential?) -> Void) {
        guard let binding else { return answer(nil) }
        binding.raise(question, for: id, answer: answer)
    }

    /// Asks the core a site's request for a capability. `answer` runs once:
    /// whether the site may use it.
    func ask(_ question: PermissionQuestion, answer: @escaping @MainActor (Bool) -> Void) {
        guard let binding else { return answer(false) }
        binding.raise(question, for: id, answer: answer)
    }

    /// Asks the core a site's request for a capability, and answers whether
    /// the site may use it. A caller that stops waiting withdraws the
    /// question, so the core records no answer the person gives it later.
    func ask(_ question: PermissionQuestion) async -> Bool {
        guard let binding else { return false }
        let promptID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                binding.raise(question, for: id, promptID: promptID) { continuation.resume(returning: $0) }
            }
        } onCancel: {
            Task { @MainActor in binding.withdraw(promptID) }
        }
    }

    // MARK: - Actions - Downloads

    /// Hands the core a download the page's web view started, which the
    /// binding runs as WebKit's own. `isUserInitiated` counts it as the
    /// person's when a trusted gesture of theirs started it.
    func startDownload(_ download: WKDownload, isUserInitiated: Bool = false) {
        guard let binding else {
            download.cancel { _ in }
            return
        }
        binding.downloads.start(download, from: self, isUserInitiated: isUserInitiated)
    }

    /// Starts a new automatic-download sequence for the page, whose document
    /// was replaced or which goes away.
    func resetAutomaticDownloads() {
        binding?.downloads.resetAutomaticSequence(of: id)
    }
}
