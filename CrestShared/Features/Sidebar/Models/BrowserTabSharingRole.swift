import Foundation

/// A tab's part in tab sharing, which names how the tab's menu stops it.
struct BrowserTabSharingRole: Hashable, Sendable {
    // MARK: - Static Variables

    /// Another page shares this tab.
    static let shared = BrowserTabSharingRole(
        name: "shared",
        stopTitle: LocalizedStringResource("Stop Sharing", comment: "Stops sharing a tab another page shares."))
    /// Another tab is shared to this page.
    static let receiving = BrowserTabSharingRole(
        name: "receiving",
        stopTitle: LocalizedStringResource(
            "Stop Sharing to This Tab", comment: "Tab menu item that stops the tab sharing shown in this page."))
    static let all = [shared, receiving]

    // MARK: - Variables

    let name: String
    /// What the tab's menu calls stopping it.
    let stopTitle: LocalizedStringResource

    // MARK: - Actions - Identity

    static func == (lhs: BrowserTabSharingRole, rhs: BrowserTabSharingRole) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
