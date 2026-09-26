import Foundation

extension CoreState {
    /// The core publishes the manual setup whole, or nil once it ends.
    func apply(_ change: SetupDraftChanged) {
        setupDraft = change.draft
    }

    /// The core publishes setup whole, or nil once it ends.
    func apply(_ change: SetupFlowChanged) {
        setupFlow = change.flow
    }

    func apply(_ change: SetupCompletedChanged) {
        setupCompleted = change.completed
    }

    /// Finishing is answered to the call that finished setup, which opens
    /// the guide; the read model holds nothing of it.
    func apply(_ change: SetupFinished) {}
}
