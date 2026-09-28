import Foundation

extension TransientPageClosed {
    /// The page stays in `state` until whatever shows it lets it go; its
    /// owner hears of it through `CrestCore.followClosedTransientPages`.
    @MainActor func apply(to state: CoreState) {}
}
