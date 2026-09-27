import Foundation

extension PageUnloaded {
    /// An unloaded page is removed by the `PageRemoved` before it; its owner
    /// hears of it through `CrestCore.followUnloadedPages`.
    @MainActor func apply(to state: CoreState) {}
}
