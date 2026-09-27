import Foundation

extension CoreState {
    // MARK: - Variables

    /// Whether the session whose journal syncs is still the disposable seed a
    /// first launch made, which the cloud's content replaces before anything
    /// syncs.
    var syncsDisposableSeed: Bool {
        guard let journal = syncJournal else { return false }
        return workspaces[journal.workspaceID]?.isDisposableSeed == true
    }

    // MARK: - Actions - Changes

    /// The journal changed. A stage reached it, so the last failure no longer
    /// stands.
    func handle(_ change: SyncJournalChanged) {
        syncJournal = change
        syncStagingFailure = nil
    }

    func handle(_ change: SyncStagingFailed) {
        syncStagingFailure = change.reason
    }

    /// A receipt for the cloud transport, which reports what it skipped; the
    /// read model keeps nothing of it.
    func handle(_ change: SyncRecordsSkipped) {}

    /// Receipts for the cloud transport about its own state, which only the
    /// transport reads.
    func handle(_ change: CloudTransportChanged) {}

    func handle(_ change: CloudMergeBegan) {}

    /// iCloud sync's status and next steps, which the sync controller keeps.
    func handle(_ change: CloudSyncAdvanced) {}
}
