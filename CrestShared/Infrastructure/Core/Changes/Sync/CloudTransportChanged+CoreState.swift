import Foundation

extension CloudTransportChanged {
    /// Receipts for the cloud transport about its own state, which only the
    /// transport reads.
    @MainActor func apply(to state: CoreState) {}
}
