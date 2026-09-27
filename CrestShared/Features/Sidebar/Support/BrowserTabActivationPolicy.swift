import Foundation

/// Selects the tab before presenting its destination.
enum BrowserTabActivationPolicy {
    enum SettingsPresentation {
        case embedded
        case sheet
    }

    enum Destination {
        case page
        case settings
    }

    /// Where activating a tab showing `content` leads.
    static func destination(
        for content: BrowserNativeTabContent?, settingsPresentation: SettingsPresentation
    ) -> Destination {
        switch settingsPresentation {
        case .embedded:
            .page
        case .sheet:
            content == .settings ? .settings : .page
        }
    }

    static func activate(
        _ tabID: UUID,
        selectTab: (UUID) -> Void,
        presentPage: () -> Void
    ) {
        selectTab(tabID)
        presentPage()
    }
}
