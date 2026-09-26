import CoreGraphics

enum BrowserReloadFeedbackPolicy {
    static let restingRotation = 0.0
    static let pressedRotation = Double(CrestLayout.reloadQuarterTurn)
    static let duration = CrestMotion.reloadFeedbackDuration
    static let phaseDuration = CrestMotion.reloadFeedbackPhaseDuration
    static let symbolPointSize: CGFloat = 14

    static func symbolName(
        isLoading: Bool,
        isPlayingFeedback: Bool
    ) -> String {
        isLoading && !isPlayingFeedback ? "xmark" : "arrow.clockwise"
    }
}
