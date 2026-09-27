import SwiftUI

struct BrowserSpaceBrandingPreset: Identifiable, Equatable, Sendable {
    let title: String
    let colors: ColorPalette
    let crest: SpaceCrest

    var id: String { title }

    /// The swatch label is user-facing. Every palette name has a hand-kept
    /// string-catalog entry, so the label goes through the catalog rather than
    /// rendering the design-token name verbatim.
    var titleKey: LocalizedStringKey { LocalizedStringKey(title) }

    static let curated = BrowserSpaceHousePalette.allCases.map {
        BrowserSpaceBrandingPreset(title: $0.name, colors: $0.colors, crest: $0.crest)
    }

    func applying(to branding: SpaceBranding) -> SpaceBranding {
        var updated = applyingPalette(to: branding)
        updated.iconStyle = .layeredCrest
        updated.crest = crest
        updated.crest.startingPresetID = id
        updated.hasCustomAppearance = false
        return updated.normalized()
    }

    func applyingPalette(to branding: SpaceBranding) -> SpaceBranding {
        var updated = branding
        updated.colors = colors
        return updated.normalized()
    }

    private func compositionMatches(_ value: SpaceCrest) -> Bool {
        var value = value
        value.startingPresetID = nil
        return value == crest
    }

    func isSelected(in branding: SpaceBranding) -> Bool {
        branding.hasCustomAppearance != true && branding.colors == colors && branding.iconStyle == .layeredCrest
            && compositionMatches(branding.crest)
    }
}
