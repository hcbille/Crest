import Foundation

extension WindowBroughtForward {
    /// What the window shows arrives through the `WindowChanged` before it;
    /// the window itself comes forward through `CrestCore.followWindowsBroughtForward`.
    @MainActor func apply(to state: CoreState) {}
}
