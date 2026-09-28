import Foundation

extension OfferedWindowAdopted {
    /// An adopted window's page arrives through the `PageOpened` before it;
    /// the window that hosts it hears of it through
    /// `CrestCore.followAdoptedWindows`.
    @MainActor func apply(to state: CoreState) {}
}
