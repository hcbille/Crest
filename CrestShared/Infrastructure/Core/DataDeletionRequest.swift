import Foundation

/// A request to erase what the engines keep for a profile, which the core
/// answers with a `DataDeleted` naming `requestID`.
protocol DataDeletionRequest: DataDeletionIntent {
    var requestID: UUID { get }
}

extension DeleteProfileData: DataDeletionRequest {}

extension DeleteSiteData: DataDeletionRequest {}

extension CoreState {
    /// A data deletion's end changes no model: `CrestCore.deleteData` hears it.
    func handle(_ change: DataDeleted) {}
}
