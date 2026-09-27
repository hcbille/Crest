import Foundation

extension CoreState {
    /// The core publishes the link preferences whole.
    func apply(_ change: LinkPreferencesChanged) {
        linkPreferences = change.preferences
    }
}
