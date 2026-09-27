import Foundation

extension CoreState {
    /// The core publishes the link preferences whole.
    func handle(_ change: LinkPreferencesChanged) {
        linkPreferences = change.preferences
    }
}
