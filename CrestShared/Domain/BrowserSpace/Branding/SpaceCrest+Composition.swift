import Foundation

/// A crest's composition as the Studio edits and the renderer draws it: the
/// ranges each control offers and the colors and figure the layers use.
extension SpaceCrest {
    // MARK: - Static Variables

    /// The most colors a crest's own palette holds, as the core enforces it.
    static var maximumPaletteCount: Int { CapacityLimits.current.crestPalette }
    static let plateScaleRange = 0.7...1.15
    static let edgeWidthRange = 0.0...1.0
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

extension CrestFieldDivision {
    /// Whether the division repeats, and so reads `SpaceCrest.divisionCount`.
    var isCounted: Bool {
        switch self {
        case .gyronny, .barry, .paly, .checky: true
        default: false
        }
    }
}

extension CrestTrim {
    /// Whether the trim is made of repeated elements, and so reads
    /// `SpaceCrest.trimDetail`.
    var isCounted: Bool {
        switch self {
        case .sunburst, .beaded: true
        default: false
        }
    }
}

extension CrestSymbol {
    // MARK: - Static Variables

    /// The figure a crest draws when it names none it can read.
    static let fallback = CrestSymbol.mountain

    /// Oak remains readable but is not offered because it renders identically
    /// to leaf.
    static let selectable: [CrestSymbol] = allCases.filter { $0 != .oak }
}

/// What a crest bears: a figure from the heraldic set, any system symbol, an
/// emoji, a monogram of up to two letters, or nothing.
extension CrestCharge {
    // MARK: - Static Variables

    /// A charge that draws nothing in place of the heraldic figure.
    static let none = CrestCharge(kind: .none, symbol: nil, text: nil, style: nil)

    // MARK: - Initializers

    static func heraldic(_ symbol: CrestSymbol) -> CrestCharge {
        CrestCharge(kind: .heraldic, symbol: symbol, text: nil, style: nil)
    }

    static func system(_ name: String) -> CrestCharge {
        CrestCharge(kind: .system, symbol: nil, text: name, style: nil)
    }

    static func emoji(_ emoji: String) -> CrestCharge {
        CrestCharge(kind: .emoji, symbol: nil, text: emoji, style: nil)
    }

    static func monogram(_ letters: String, _ style: CrestMonogramStyle) -> CrestCharge {
        CrestCharge(kind: .monogram, symbol: nil, text: letters, style: style)
    }
}
