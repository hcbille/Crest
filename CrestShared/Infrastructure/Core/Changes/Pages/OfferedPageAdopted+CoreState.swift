import Foundation

extension OfferedPageAdopted {
    /// An adopted page arrives through the `PageOpened` before it; the window
    /// that hosts it hears of it through `CrestCore.followAdoptedPages`.
    @MainActor func apply(to state: CoreState) {}
}
