enum BrowserSpaceBrandingControlPolicy {
    static let gradientAngleStep = 15.0

    static func adjustedAngle(
        _ angle: Double,
        direction: BrowserSpaceGradientAngleAdjustmentDirection
    ) -> Double {
        let delta =
            direction == .increment
            ? gradientAngleStep
            : -gradientAngleStep
        let remainder = (angle + delta).truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}
