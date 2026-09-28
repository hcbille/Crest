import Foundation

/// A crest's composition as the Studio edits and the renderer draws it: the
/// ranges each control offers and the colors and figure the layers use.
extension SpaceCrest {
    // MARK: - Static Variables

    /// The most colors a crest's own palette holds, as the core enforces it.
    static var maximumPaletteCount: Int { CapacityLimits.current.crestPalette }
    static let plateScaleRange = 0.7...1.15
    static let divisionCountRange = 2...8
    static let ordinaryWidthRange = 0.5...1.6
    static let trimWeightRange = 0.5...2.0
    static let trimDetailRange = 6...24
    static let chargeScaleRange = 0.6...1.5
    static let chargeOffsetRange = -0.2...0.2

    // MARK: - Variables

    /// The figure this crest draws: a custom charge when one was chosen, else
    /// the heraldic symbol.
    var resolvedCharge: CrestCharge {
        charge ?? .heraldic(symbol)
    }

    /// Whether the crest draws with its own tinctures rather than the Space's.
    var usesOwnPalette: Bool { palette != nil }

    // MARK: - Actions - Colors

    /// The colors this crest's layer indices point into.
    func layerColors(spaceColors: ColorPalette) -> ColorPalette {
        if let palette, !palette.isEmpty { return palette }
        return spaceColors.isEmpty ? [.indigo] : spaceColors
    }
}
