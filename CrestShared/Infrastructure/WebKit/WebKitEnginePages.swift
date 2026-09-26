import WebKit

/// WebKit's direct path from the platform to the pages its binding built: it
/// answers each page request against the page's web view, and presents what
/// finishes later, such as a find's count, to the page that asked.
@MainActor
final class WebKitEnginePages: EnginePages {
    // MARK: - Variables

    private unowned let binding: WebKitEngineBinding
    /// The pages that hear the presentations about them.
    private var attached = AttachedEnginePages()

    // MARK: - Initializers

    init(binding: WebKitEngineBinding) {
        self.binding = binding
    }

    // MARK: - Actions - Requests

    func attach(_ page: EnginePage) {
        attached.attach(page)
    }

    /// Answers `request` for one of the binding's pages. One for a page that is
    /// gone answers that nothing was done.
    @discardableResult
    func request<Request: PageRequest>(_ request: Request) -> Request.Answer {
        switch request {
        case let going as GoToHistoryOffset:
            return answer(page(going.pageID).map { $0.engine.navigateHistory(by: going.offset) } != nil)
        case let reloading as ReloadPage:
            let reloaded = page(reloading.pageID)
            reloaded?.engine.reload(bypassingCache: reloading.bypassesCache)
            return answer(reloaded != nil)
        case let stopping as StopLoading:
            return answer(page(stopping.pageID).map { $0.webView.stopLoading() } != nil)
        case let zooming as ZoomPage:
            return answer(page(zooming.pageID).map { $0.webView.pageZoom = CGFloat(zooming.factor) } != nil)
        case let finding as FindInPage:
            return answer(find(finding))
        case let saving as SaveInteractionState:
            return answer(InteractionState(state: page(saving.pageID)?.engine.savedHistory()))
        case let restoring as RestoreInteractionState:
            return answer(page(restoring.pageID)?.engine.restoreHistory(restoring.state) ?? false)
        default:
            preconditionFailure("WebKit answers no \(Request.self).")
        }
    }

    private func page(_ pageID: UUID) -> WebKitEnginePage? {
        binding.page(pageID)
    }

    /// The answer a request's own type names, which each case above builds.
    private func answer<Answer>(_ value: Any) -> Answer {
        guard let typed = value as? Answer else {
            preconditionFailure("WebKit built the wrong answer for \(Answer.self).")
        }
        return typed
    }

    // MARK: - Actions - Find

    /// Finds text in the page, and presents its count once WebKit has it.
    private func find(_ finding: FindInPage) -> Bool {
        guard let page = page(finding.pageID) else { return false }
        let configuration = BrowserFindConfiguration(backwards: finding.backwards, caseSensitive: finding.caseSensitive)
        page.webView.performFind(finding.query, configuration: configuration) { [weak self] result in
            // WebKit tells only whether it found a match, never how many.
            let finished = FindFinished(pageID: finding.pageID, matches: result.matchFound ? nil : 0, activeMatch: 0)
            self?.attached.present(.findFinished(finished))
        }
        return true
    }
}
