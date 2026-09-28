import AppKit

/// A command of the application rather than of a window, which the menu bar
/// offers under the application's and the Help menus and the shell runs.
@MainActor
struct BrowserMacApplicationAction: Hashable {
    // MARK: - Static Variables

    static let about = BrowserMacApplicationAction(name: "about", title: "About Crest") { $0.showAbout() }
    static let updates = BrowserMacApplicationAction(
        name: "updates", title: "Check for Updates…", isEnabled: { $0.canCheckForUpdates },
        perform: { $0.checkForUpdates() })
    static let settings = BrowserMacApplicationAction(name: "settings", title: "Settings…", keyEquivalent: ",") {
        $0.openSettings()
    }
    static let gettingStarted = BrowserMacApplicationAction(
        name: "getting-started", title: "Getting Started with Crest"
    ) { $0.openGettingStarted() }
    static let all: [BrowserMacApplicationAction] = [about, updates, settings, gettingStarted]

    // MARK: - Variables

    /// The action's name, which identifies it.
    nonisolated let name: String
    let title: LocalizedStringResource
    /// The key that runs it with Command, or none.
    let keyEquivalent: String
    private let availability: @MainActor (BrowserMacShell) -> Bool
    private let run: @MainActor (BrowserMacShell) -> Void

    // MARK: - Initializers

    private init(
        name: String, title: LocalizedStringResource, keyEquivalent: String = "",
        isEnabled: @escaping @MainActor (BrowserMacShell) -> Bool = { _ in true },
        perform: @escaping @MainActor (BrowserMacShell) -> Void
    ) {
        self.name = name
        self.title = title
        self.keyEquivalent = keyEquivalent
        availability = isEnabled
        run = perform
    }

    // MARK: - Actions - Running

    /// Whether `shell` can run the action now.
    func isEnabled(in shell: BrowserMacShell) -> Bool {
        availability(shell)
    }

    /// Runs the action in `shell`.
    func perform(in shell: BrowserMacShell) {
        run(shell)
    }
}

// MARK: - Hashable

extension BrowserMacApplicationAction {
    nonisolated static func == (lhs: BrowserMacApplicationAction, rhs: BrowserMacApplicationAction) -> Bool {
        lhs.name == rhs.name
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
