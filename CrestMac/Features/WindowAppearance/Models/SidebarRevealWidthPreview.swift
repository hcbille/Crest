import Observation

/// Tells every browser window that the sidebar hover area is being adjusted,
/// so each can outline it for a moment.
///
/// Settings lives in its own window, away from the edge it is resizing; this is
/// the only way the person dragging the slider can see what the number means.
@MainActor
@Observable
final class SidebarRevealWidthPreview {
    static let shared = SidebarRevealWidthPreview()

    /// Changes on every adjustment; windows restart their fade when it does.
    private(set) var adjustmentCount = 0

    func adjusted() {
        adjustmentCount += 1
    }
}
