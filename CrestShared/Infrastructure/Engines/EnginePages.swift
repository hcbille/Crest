import Foundation

/// One engine's direct path from the platform to its pages: view work such as
/// going back, reloading or finding text, which the engine answers at once,
/// and the presentations it sends when work finishes later. Every engine
/// answers the same requests; the core never sees them.
@MainActor
protocol EnginePages: AnyObject {
    /// Asks the engine for `request` and answers what it answered.
    @discardableResult
    func request<Request: PageRequest>(_ request: Request) -> Request.Answer

    /// Sends `page` the presentations about it, while it lives.
    func attach(_ page: EnginePage)
}

/// The pages attached to one engine's direct path, held weakly so each goes
/// with its owner.
@MainActor
struct AttachedEnginePages {
    // MARK: - Types

    private struct WeakPage {
        weak var page: EnginePage?
    }

    // MARK: - Variables

    private var pages: [UUID: WeakPage] = [:]

    // MARK: - Actions - Pages

    mutating func attach(_ page: EnginePage) {
        pages = pages.filter { $0.value.page != nil }
        pages[page.id] = WeakPage(page: page)
    }

    /// Hands a presentation to the page it is about, if that page is attached.
    func present(_ presentation: EnginePresentation) {
        guard let pageID = presentation.pageID else { return }
        pages[pageID]?.page?.receive(presentation)
    }
}

extension EnginePresentation {
    /// The page the presentation is about, or none for a profile's.
    var pageID: UUID? {
        switch self {
        case .extensionsChanged, .profilePrepared, .profileReleased:
            nil
        case .contentFullscreenChanged(let value): value.pageID
        case .contentMessagePosted(let value): value.pageID
        case .contentScriptEvaluated(let value): value.pageID
        case .findFinished(let value): value.pageID
        case .infoBarRemoved(let value): value.pageID
        case .infoBarShown(let value): value.pageID
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
        case .peekRequested(let value): value.pageID
        case .popupBlocked(let value): value.pageID
        case .storeInstallRequested(let value): value.pageID
        case .storeRemovalRequested(let value): value.pageID
        }
    }
}
