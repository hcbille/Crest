import Foundation

/// The locked Spaces of a Space-value list. TRANSITIONAL for the portability
/// export, which pass 3 moves to the read model; settings panes ask the access
/// controller about Spaces of the read model directly.
@MainActor
enum BrowserSettingsPrivacyPolicy {
    // MARK: - Actions

    static func lockedSpaces(
        in spaces: [BrowserSpace],
        accessController: BrowserSpaceAccessController
    ) -> [BrowserSpace] {
        spaces.filter(accessController.isLocked)
    }
}
