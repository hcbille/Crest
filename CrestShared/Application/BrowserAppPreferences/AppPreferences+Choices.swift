import Foundation

extension StartupBehavior {
    // MARK: - Static Variables

    /// The choices, in the order the settings offer them.
    static let settingsOrder: [StartupBehavior] = [.lastActiveTab, .showStartPage]

    // MARK: - Variables

    var title: String {
        switch self {
        case .lastActiveTab: "Open Last Active Tab"
        case .showStartPage: "Show Start Page"
        }
    }

    var activatesRestoredTab: Bool {
        self == .lastActiveTab
    }
}

extension SavedTabClosePolicy {
    // MARK: - Variables

    var title: LocalizedStringResource {
        switch self {
        case .resumeLastLocation: "Resume last location"
        case .returnToSavedURL: "Return to saved URL"
        }
    }
}
