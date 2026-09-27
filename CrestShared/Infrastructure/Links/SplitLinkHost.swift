import Foundation

/// Split-level link operations a page needs from whatever owns its tabs. Both
/// are synchronous because AppKit is building a context menu on the main thread
/// when it asks, and a menu cannot wait for an answer.
@MainActor
struct BrowserSplitLinkHost {
    var canOpenLink: (UUID, BrowserSpaceRuntimeAssignment) -> Bool
    var openLink: (URL, UUID, BrowserSpaceRuntimeAssignment) -> Void

    init(
        canOpenLink: @escaping (UUID, BrowserSpaceRuntimeAssignment) -> Bool,
        openLink: @escaping (URL, UUID, BrowserSpaceRuntimeAssignment) -> Void
    ) {
        self.canOpenLink = canOpenLink
        self.openLink = openLink
    }

    /// Offers no split at all. Pools built without a store (tests, previews)
    /// simply leave the menu item out.
    static let unavailable = BrowserSplitLinkHost(
        canOpenLink: { _, _ in false },
        openLink: { _, _, _ in }
    )
}
