import Foundation

enum BrowserSpaceForegroundPolicy {
    /// The tone that reads best over `branding`'s banner, unless its text color
    /// mode names one.
    static func tone(
        for branding: SpaceBranding
    ) -> BrowserSpaceForegroundTone {
        if let override = branding.textColorMode.foregroundTone { return override }
        return tone(
            over: branding.colors.isEmpty ? [.indigo] : branding.colors, strength: branding.bannerStrength,
            readabilityFade: branding.readabilityFade)
    }

    /// The tone that reads best over one solid `color`.
    static func tone(over color: BrandColor) -> BrowserSpaceForegroundTone {
        tone(over: [color], strength: 1, readabilityFade: 0)
    }

    private static func tone(
        over colors: ColorPalette,
        strength: Double,
        readabilityFade: Double
    ) -> BrowserSpaceForegroundTone {
        let lightContrast = minimumContrast(
            for: .light,
            colors: colors,
            strength: strength,
            readabilityFade: readabilityFade
        )
        let darkContrast = minimumContrast(
            for: .dark,
            colors: colors,
            strength: strength,
            readabilityFade: readabilityFade
        )
        return lightContrast >= darkContrast ? .light : .dark
    }

    private static func minimumContrast(
        for tone: BrowserSpaceForegroundTone,
        colors: ColorPalette,
        strength: Double,
        readabilityFade: Double
    ) -> Double {
        let baseChannel = tone == .light ? 0.0 : 1.0
        let textLuminance = tone == .light ? 1.0 : 0.0
        let readabilityOverlay = min(readabilityFade * 0.55, 0.7)

        return colors.map { color in
            let red = renderedChannel(
                color.red,
                base: baseChannel,
                strength: strength,
                overlay: readabilityOverlay
            )
            let green = renderedChannel(
                color.green,
                base: baseChannel,
                strength: strength,
                overlay: readabilityOverlay
            )
            let blue = renderedChannel(
                color.blue,
                base: baseChannel,
                strength: strength,
                overlay: readabilityOverlay
            )
            let backgroundLuminance =
                0.2126 * linearComponent(red)
                + 0.7152 * linearComponent(green)
                + 0.0722 * linearComponent(blue)
            let lighter = max(textLuminance, backgroundLuminance)
            let darker = min(textLuminance, backgroundLuminance)
            return (lighter + 0.05) / (darker + 0.05)
        }
        .min() ?? 1
    }

    private static func renderedChannel(
        _ channel: Double,
        base: Double,
        strength: Double,
        overlay: Double
    ) -> Double {
        let composited = channel * strength + base * (1 - strength)
        return composited * (1 - overlay)
    }

    private static func linearComponent(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}
