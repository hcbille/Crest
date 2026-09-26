import Foundation

#if os(macOS)
    import AppKit
#endif

/// One tab's resident page, and on the Mac which window presents it.
@MainActor
final class BrowserTabRuntime {
    var page: BrowserPlatformPage
    #if os(macOS)
        weak var store: BrowserPageRuntimeStore?
        var presentationWindowID: BrowserWindowID?
        var routingWindowID: BrowserWindowID?
        var snapshotGeneration = 0
        var snapshot: NSImage?
    #endif

    var allPages: [BrowserPlatformPage] { [page] }

    init(page: BrowserPlatformPage) {
        self.page = page
    }

    /// Ends every page the tab holds; see `release(keepingState:)` on the page.
    func release(keepingState: Bool) {
        for page in allPages {
            page.release(keepingState: keepingState)
        }
    }

    /// Ends the tab's page the core unloaded; see `unloaded()` on the page.
    func unloaded() {
        page.unloaded()
    }
}
