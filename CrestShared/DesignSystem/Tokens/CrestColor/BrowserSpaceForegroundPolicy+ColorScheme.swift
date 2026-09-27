import SwiftUI

extension BrowserSpaceForegroundPolicy {
    static func colorScheme(for branding: SpaceBranding) -> ColorScheme {
        tone(for: branding) == .light ? .dark : .light
    }

    static func colorScheme(over color: BrandColor) -> ColorScheme {
        tone(over: color) == .light ? .dark : .light
    }
}
