import Foundation

extension DataDeleted {
    /// A data deletion's end changes no model: `CrestCore.deleteData` hears it.
    @MainActor func apply(to state: CoreState) {}
}
