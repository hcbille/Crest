import AppKit
import WebKit

/// One tab's live WebKit page and native presentation ownership.
@MainActor
final class BrowserTabRuntime {
    weak var store: BrowserPageRuntimeStore?
    var presentationWindowID: BrowserWindowID?
    var routingWindowID: BrowserWindowID?
    var snapshotGeneration = 0
    var snapshot: NSImage?
    var page: BrowserPage

    var allPages: [BrowserPage] { [page] }

    init(page: BrowserPage) {
        self.page = page
    }

    /// Ends every page the tab holds; see `BrowserPage.release(keepingState:)`.
    func release(keepingState: Bool) {
        for page in allPages {
            page.release(keepingState: keepingState)
        }
    }

    /// Ends the tab's page the core unloaded; see `BrowserPage.unloaded()`.
    func unloaded() {
        page.unloaded()
    }
}
