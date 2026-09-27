import Foundation

extension StorageFailed {
    @MainActor func apply(to state: CoreState) {
        state.storageFailure = reason
    }
}
