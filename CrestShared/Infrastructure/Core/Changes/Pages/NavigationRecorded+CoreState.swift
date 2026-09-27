import Foundation

extension NavigationRecorded {
    /// A recorded navigation changes no page: the session changes before it
    /// carry what it recorded, and `CrestCore` tells the engines' observers.
    @MainActor func apply(to state: CoreState) {}
}
