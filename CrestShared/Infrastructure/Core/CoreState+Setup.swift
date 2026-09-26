import Foundation

extension CoreState {
    /// The core publishes the manual setup whole, or nil once it ends.
    func apply(_ change: SetupDraftChanged) {
        setupDraft = change.draft
    }
}
