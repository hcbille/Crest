import Foundation

/// The platform's direct path to one page's engine, whichever engine hosts
/// it: going back and forward, reloading, stopping, zooming, finding text and
/// keeping the page's history. None of it changes browser state; what it
/// causes, such as a committed navigation, reaches the core as the engine's
/// events.
@MainActor
final class EnginePage: BrowserFindExecuting {
    // MARK: - Variables

    /// The core's page this one is.
    let id: UUID
    private let pages: any EnginePages
    /// The engine and version the page's saved history belongs to, which a
    /// restore must match.
    private let historyFamily: BrowserEngineImplementation.Family
    private let historyVersion: @MainActor () -> String?
    /// What waits for the engine to count the page's latest find.
    private var findCompletion: (@MainActor (BrowserFindResult) -> Void)?

    // MARK: - Initializers

    /// The direct path to page `id` over `pages`, whose saved history belongs
    /// to `historyFamily` at the version `historyVersion` names.
    init(
        id: UUID, pages: any EnginePages, historyFamily: BrowserEngineImplementation.Family,
        historyVersion: @escaping @MainActor () -> String?
    ) {
        self.id = id
        self.pages = pages
        self.historyFamily = historyFamily
        self.historyVersion = historyVersion
        pages.attach(self)
    }

    // MARK: - Actions - Navigation

    /// Moves `offset` entries through the page's history: back when negative.
    func goToHistory(offset: Int) {
        guard offset != 0 else { return }
        pages.request(GoToHistoryOffset(pageID: id, offset: offset))
    }

    func reload(bypassingCache: Bool = false) {
        pages.request(ReloadPage(pageID: id, bypassesCache: bypassingCache))
    }

    func stop() {
        pages.request(StopLoading(pageID: id))
    }

    /// Shows the page at `factor` of its normal size.
    func zoom(to factor: CGFloat) {
        pages.request(ZoomPage(pageID: id, factor: Double(factor)))
    }

    // MARK: - Actions - History

    /// The page's history as the engine keeps it, to restore later on the same
    /// engine and version; nil when it has none.
    func savedHistory() -> Data? {
        guard let version = historyVersion(),
            let state = pages.request(SaveInteractionState(pageID: id)).state
        else { return nil }
        return BrowserEngineInteractionState(engine: historyFamily, version: version, payload: state).encoded()
    }

    /// Restores history `savedHistory()` kept, in place of the page's first
    /// load of `url`; false when it belongs to another engine or version, or
    /// the engine refused it.
    func restoreHistory(_ saved: Data, expecting url: URL) -> Bool {
        guard let version = historyVersion(),
            let payload = BrowserEngineInteractionState.payload(saved, engine: historyFamily, version: version)
        else { return false }
        return pages.request(RestoreInteractionState(pageID: id, state: payload, expectedURL: url.absoluteString))
    }

    // MARK: - Actions - Find

    /// Finds `query` in the page. A new find replaces the one waiting for its
    /// count.
    func performFind(
        _ query: String, configuration: BrowserFindConfiguration,
        completion: @escaping @MainActor (BrowserFindResult) -> Void
    ) {
        findCompletion = nil
        guard
            pages.request(
                FindInPage(
                    pageID: id, query: query, backwards: configuration.backwards,
                    caseSensitive: configuration.caseSensitive))
        else {
            completion(.notFound)
            return
        }
        findCompletion = completion
    }

    // MARK: - Actions - Presentations

    /// Hears what the engine finished for the page.
    func receive(_ presentation: EnginePresentation) {
        switch presentation {
        case .findFinished(let finished):
            let completion = findCompletion
            findCompletion = nil
            completion?(
                finished.matches.map { BrowserFindResult(matchCount: $0, activeMatch: finished.activeMatch) }
                    ?? BrowserFindResult(matchFound: true))
        default:
            break
        }
    }
}
