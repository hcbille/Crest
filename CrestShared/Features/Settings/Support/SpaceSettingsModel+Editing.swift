import Foundation

/// A Space's settings as the settings panes edit them: the Swift preference
/// values the panes bind their controls to, read from what the core published.
/// TRANSITIONAL until S6.7 retires the Swift preference values.
extension SpaceSettingsModel {
    // MARK: - Variables

    /// The browsing preferences, with the selected engine resolved.
    var editableBrowsingPreferences: BrowserSpaceBrowsingPreferences {
        BrowserSpaceBrowsingPreferences(core: browsingPreferences)
    }

    /// Whether the Space uses Crest Passwords, and how.
    var editableCredentialPreferences: BrowserCredentialPreferences {
        BrowserCredentialPreferences(
            isEnabled: credentialPreferences.isEnabled,
            syncsCrestPasswordsWithICloud: credentialPreferences.syncsCrestPasswordsWithICloud,
            alsoOffersSaveToSystemPasswords: credentialPreferences.alsoOffersSaveToSystemPasswords)
    }
}
