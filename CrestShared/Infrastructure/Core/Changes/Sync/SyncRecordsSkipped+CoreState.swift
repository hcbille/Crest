import Foundation

extension SyncRecordsSkipped {
    /// A receipt for the cloud transport, which reports what it skipped; the
    /// read model keeps nothing of it.
    @MainActor func apply(to state: CoreState) {}
}
