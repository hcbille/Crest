import Foundation

/// The named colors Crest offers and draws with.
extension BrandColor {
    // MARK: - Static Variables

    static let ink = BrandColor(red: 0.08, green: 0.15, blue: 0.23, alpha: 1)
    static let indigo = BrandColor(red: 0.29, green: 0.25, blue: 0.58, alpha: 1)
    static let ocean = BrandColor(red: 0.22, green: 0.42, blue: 0.64, alpha: 1)
    static let sky = BrandColor(red: 0.35, green: 0.66, blue: 0.84, alpha: 1)
    static let teal = BrandColor(red: 0.12, green: 0.49, blue: 0.52, alpha: 1)
    static let sage = BrandColor(red: 0.39, green: 0.56, blue: 0.42, alpha: 1)
    static let gold = BrandColor(red: 0.88, green: 0.67, blue: 0.25, alpha: 1)
    static let ember = BrandColor(red: 0.85, green: 0.27, blue: 0.20, alpha: 1)
    static let rose = BrandColor(red: 0.72, green: 0.25, blue: 0.42, alpha: 1)
    static let sand = BrandColor(red: 0.82, green: 0.72, blue: 0.56, alpha: 1)
    static let folderDefault = BrandColor(red: 0.43, green: 0.48, blue: 0.54, alpha: 1)

    static let presets: [BrandColor] = [
        .ink, .indigo, .ocean, .sky, .teal, .sage, .gold, .ember, .rose, .sand,
    ]

    // MARK: - House palette tinctures
    //
    // Crest's shipped palettes are built like arms: a deep field, one related
    // tincture a value step above it, and a single luminous charge. Fields and
    // primaries stay below the flip point that `BrowserSpaceForegroundPolicy`
    // uses, so a whole palette resolves to one light foreground and sidebar text
    // never changes tone across the banner.

    static let winterSlate = BrandColor(red: 0.118, green: 0.157, blue: 0.200, alpha: 1)
    static let winterSteel = BrandColor(red: 0.243, green: 0.306, blue: 0.369, alpha: 1)
    static let winterIce = BrandColor(red: 0.525, green: 0.678, blue: 0.769, alpha: 1)

    static let lionOxblood = BrandColor(red: 0.235, green: 0.055, blue: 0.102, alpha: 1)
    static let lionCrimson = BrandColor(red: 0.447, green: 0.125, blue: 0.188, alpha: 1)
    static let lionGold = BrandColor(red: 0.788, green: 0.635, blue: 0.329, alpha: 1)

    static let stormMidnight = BrandColor(red: 0.082, green: 0.094, blue: 0.141, alpha: 1)
    static let stormGunmetal = BrandColor(red: 0.192, green: 0.220, blue: 0.282, alpha: 1)
    static let stormBrass = BrandColor(red: 0.690, green: 0.561, blue: 0.290, alpha: 1)

    static let dragonChar = BrandColor(red: 0.102, green: 0.063, blue: 0.051, alpha: 1)
    static let dragonBlood = BrandColor(red: 0.478, green: 0.118, blue: 0.071, alpha: 1)
    static let dragonScarlet = BrandColor(red: 0.745, green: 0.267, blue: 0.220, alpha: 1)

    static let meadowForest = BrandColor(red: 0.082, green: 0.137, blue: 0.094, alpha: 1)
    static let meadowMoss = BrandColor(red: 0.204, green: 0.341, blue: 0.220, alpha: 1)
    static let meadowWheat = BrandColor(red: 0.737, green: 0.655, blue: 0.400, alpha: 1)

    static let ironBlack = BrandColor(red: 0.055, green: 0.102, blue: 0.110, alpha: 1)
    static let ironPewter = BrandColor(red: 0.173, green: 0.227, blue: 0.235, alpha: 1)
    static let ironPatina = BrandColor(red: 0.612, green: 0.592, blue: 0.506, alpha: 1)

    static let riverNavy = BrandColor(red: 0.059, green: 0.118, blue: 0.180, alpha: 1)
    static let riverLapis = BrandColor(red: 0.133, green: 0.282, blue: 0.424, alpha: 1)
    static let riverRust = BrandColor(red: 0.659, green: 0.361, blue: 0.255, alpha: 1)

    static let sunUmber = BrandColor(red: 0.208, green: 0.086, blue: 0.043, alpha: 1)
    static let sunTerracotta = BrandColor(red: 0.545, green: 0.239, blue: 0.106, alpha: 1)
    static let sunDune = BrandColor(red: 0.816, green: 0.620, blue: 0.396, alpha: 1)

    static let vigilOnyx = BrandColor(red: 0.063, green: 0.067, blue: 0.071, alpha: 1)
    static let vigilCharcoal = BrandColor(red: 0.153, green: 0.165, blue: 0.180, alpha: 1)
    static let vigilAsh = BrandColor(red: 0.482, green: 0.514, blue: 0.549, alpha: 1)

    // MARK: - Initializers

    /// An opaque color, each component kept within 0 through 1.
    init(red: Double, green: Double, blue: Double) {
        self.init(clampingRed: red, green: green, blue: blue, alpha: 1)
    }

    /// A color as a color picker or the system gives it, each component kept
    /// within 0 through 1.
    init(clampingRed red: Double, green: Double, blue: Double, alpha: Double) {
        self.init(red: Self.unit(red), green: Self.unit(green), blue: Self.unit(blue), alpha: Self.unit(alpha))
    }

    // MARK: - Actions - Components

    private static func unit(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }
}

extension BrandColor: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(red)
        hasher.combine(green)
        hasher.combine(blue)
        hasher.combine(alpha)
    }
}

/// A color as the device's appearance settings store it: its components,
/// opaque unless it says.
extension BrandColor: Codable {
    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            clampingRed: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            alpha: try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
    }
}
