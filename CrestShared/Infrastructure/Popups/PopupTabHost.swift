import Foundation

/// The tab-level operation a page pool needs for pages web content opened:
/// closing the tab of one that closed itself, as `window.close()` does.
@MainActor
struct BrowserPopupTabHost {
    var closeTab: (UUID, UUID) -> Void

    init(closeTab: @escaping (UUID, UUID) -> Void) {
        self.closeTab = closeTab
    }

    /// Closes nothing, for pools built without a tab host (tests, previews).
    static let unavailable = BrowserPopupTabHost(closeTab: { _, _ in })
}
