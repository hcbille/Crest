import SwiftUI

/// A term in Crest's heraldic vocabulary.
///
/// Every one of these names is a design token *and* a visible gallery label, so
/// each carries an English name for the code to reason about and a catalog key
/// for the reader to see. The catalog entries are hand-kept: `titleKey` builds a
/// key from a runtime string, which the compiler cannot extract, so a term added
/// here needs its entry added to `Localizable.xcstrings` by hand.
protocol BrowserSpaceHeraldicTerm {
    var title: String { get }
}

extension BrowserSpaceHeraldicTerm {
    var titleKey: LocalizedStringKey { LocalizedStringKey(title) }
}

extension SpaceIconStyle: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .simpleSymbol: "Simple Symbol"
        case .layeredCrest: "Layered Crest"
        }
    }
}

extension SpaceBannerPattern: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .solid: "Solid"
        case .split: "Split"
        case .bands: "Bands"
        case .diagonal: "Diagonal"
        case .chevron: "Chevron"
        case .quartered: "Quartered"
        case .stripes: "Stripes"
        case .checkered: "Checkered"
        case .lozenges: "Lozenges"
        }
    }
}

extension CrestBackplate: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .none: "None"
        case .circle: "Round"
        case .shield: "Shield"
        case .frenchShield: "French Shield"
        case .diamond: "Lozenge"
        case .seal: "Seal"
        case .hexagon: "Hexagon"
        case .octagon: "Octagon"
        case .roundedSquare: "Rounded Square"
        case .oval: "Oval"
        case .banner: "Banner"
        case .badge: "Badge"
        }
    }

    /// The system glyph that stands for the plate in galleries that cannot draw
    /// the plate itself. Plates without a close glyph borrow the nearest one.
    var systemImage: String? {
        switch self {
        case .none: nil
        case .circle: "circle.fill"
        case .shield: "shield.fill"
        case .diamond: "diamond.fill"
        case .seal: "seal.fill"
        case .hexagon: "hexagon.fill"
        case .octagon: "octagon.fill"
        case .roundedSquare: "square.fill"
        case .frenchShield: "shield.fill"
        case .oval: "oval.fill"
        case .banner: "flag.fill"
        case .badge: "seal.fill"
        }
    }

}

extension CrestChargeLayout: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .single: "One"
        case .paired: "Two"
        case .trio: "Three"
        case .quad: "Four"
        case .ring: "Ring"
        }
    }
}

extension CrestFieldDivision: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        // Kept to one word: these are gallery card captions under a 46pt crest,
        // and the card already shows what the division does.
        case .plain: "Plain"
        case .perPale: "Vertical"
        case .perFess: "Horizontal"
        case .perBend: "Diagonal"
        case .perChevron: "Chevron"
        case .quarterly: "Quartered"
        case .perSaltire: "Crossed"
        case .gyronny: "Wedges"
        case .barry: "Bars"
        case .paly: "Stripes"
        case .checky: "Checks"
        }
    }
}

extension CrestOrdinary: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .none: "None"
        case .pale: "Pale"
        case .fess: "Fess"
        case .bend: "Bend"
        case .chevron: "Chevron"
        case .cross: "Cross"
        case .saltire: "Saltire"
        case .chief: "Chief"
        case .bordure: "Bordure"
        case .pall: "Pall"
        case .pile: "Pile"
        case .canton: "Canton"
        case .roundel: "Roundel"
        }
    }
}

extension CrestTrim: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .none: "None"
        case .shield: "Shield"
        case .line: "Line"
        case .doubleLine: "Double Line"
        case .laurel: "Laurel"
        case .sunburst: "Sunburst"
        case .doubleRing: "Double Ring"
        case .seal: "Seal"
        case .beaded: "Beaded"
        }
    }
}

extension CrestSymbol: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .dragon: "Dragon"
        case .direwolf: "Direwolf"
        case .lion: "Lion"
        case .stag: "Stag"
        case .raven: "Raven"
        case .griffin: "Griffin"
        case .eagle: "Eagle"
        case .bear: "Bear"
        case .boar: "Boar"
        case .fox: "Fox"
        case .horse: "Horse"
        case .unicorn: "Unicorn"
        case .wyvern: "Wyvern"
        case .hydra: "Hydra"
        case .serpent: "Serpent"
        case .kraken: "Kraken"
        case .seahorse: "Seahorse"
        case .scorpion: "Scorpion"
        case .bat: "Bat"
        case .falcon: "Falcon"
        case .rose: "Rose"
        case .lily: "Fleur-de-lis"
        case .pine: "Pine"
        case .willow: "Willow"
        case .swords: "Crossed Swords"
        case .axes: "Crossed Axes"
        case .sword: "Sword"
        case .trident: "Trident"
        case .anchor: "Anchor"
        case .castle: "Castle"
        case .scales: "Scales"
        case .dragonHead: "Dragon Head"
        case .hound: "Hound"
        case .paw: "Paw"
        case .hare: "Hare"
        case .bird: "Bird"
        case .fish: "Fish"
        // Named for the glyph that actually draws, not the glyph Crest wished for.
        case .bee: "Beetle"
        case .shell: "Shell"
        case .sun: "Sun"
        case .risingSun: "Rising Sun"
        case .crescent: "Crescent"
        case .star: "Star"
        case .sparkles: "Sparkles"
        case .lightning: "Lightning"
        case .flame: "Flame"
        case .snowflake: "Snowflake"
        case .drop: "Drop"
        case .mountain: "Mountain"
        case .tree: "Tree"
        case .oak: "Oak"
        case .leaf: "Leaf"
        case .fern: "Frond"
        case .flower: "Flower"
        case .waves: "Waves"
        case .tower: "Tower"
        case .book: "Book"
        case .key: "Key"
        case .hammer: "Hammer"
        case .compass: "Compass"
        case .sailboat: "Sailboat"
        case .crown: "Crown"
        case .horn: "Horn"
        case .crossedBanners: "Banners"
        }
    }

    /// The bundled artwork that draws the figure, if it has any; the others
    /// draw their system glyph.
    var assetName: String? {
        switch self {
        case .dragon: "CrestCharge-dragon"
        case .direwolf: "CrestCharge-direwolf"
        case .lion: "CrestCharge-lion"
        case .stag: "CrestCharge-stag"
        case .raven: "CrestCharge-raven"
        case .griffin: "CrestCharge-griffin"
        case .eagle: "CrestCharge-eagle"
        case .bear: "CrestCharge-bear"
        case .boar: "CrestCharge-boar"
        case .fox: "CrestCharge-fox"
        case .horse: "CrestCharge-horse"
        case .unicorn: "CrestCharge-unicorn"
        case .wyvern: "CrestCharge-wyvern"
        case .hydra: "CrestCharge-hydra"
        case .serpent: "CrestCharge-serpent"
        case .kraken: "CrestCharge-kraken"
        case .seahorse: "CrestCharge-seahorse"
        case .scorpion: "CrestCharge-scorpion"
        case .bat: "CrestCharge-bat"
        case .falcon: "CrestCharge-falcon"
        case .rose: "CrestCharge-rose"
        case .lily: "CrestCharge-lily"
        case .pine: "CrestCharge-pine"
        case .willow: "CrestCharge-willow"
        case .swords: "CrestCharge-swords"
        case .axes: "CrestCharge-axes"
        case .sword: "CrestCharge-sword"
        case .trident: "CrestCharge-trident"
        case .anchor: "CrestCharge-anchor"
        case .castle: "CrestCharge-castle"
        case .scales: "CrestCharge-scales"
        case .dragonHead: "CrestCharge-dragonHead"
        default: nil
        }
    }

    var systemImage: String {
        switch self {
        case .dragon: "flame.fill"
        case .direwolf: "dog.fill"
        case .lion: "pawprint.fill"
        case .stag: "leaf.fill"
        case .raven, .griffin: "bird.fill"
        case .eagle, .bear, .boar, .fox, .horse, .unicorn, .wyvern, .hydra, .serpent, .kraken, .seahorse, .scorpion,
            .bat, .falcon, .rose, .lily, .pine, .willow, .swords, .axes, .sword, .trident, .anchor, .castle, .scales,
            .dragonHead:
            "shield.fill"
        case .hound: "dog.fill"
        case .paw: "pawprint.fill"
        case .hare: "hare.fill"
        case .bird: "bird.fill"
        case .fish: "fish.fill"
        case .bee: "ladybug.fill"
        case .shell: "fossil.shell.fill"
        case .sun: "sun.max.fill"
        case .risingSun: "sun.horizon.fill"
        case .crescent: "moon.fill"
        case .star: "star.fill"
        case .sparkles: "sparkles"
        case .lightning: "bolt.fill"
        case .flame: "flame.fill"
        case .snowflake: "snowflake"
        case .drop: "drop.fill"
        case .mountain: "mountain.2.fill"
        case .tree: "tree.fill"
        // `oak` has no symbol of its own and draws `leaf`'s; it is kept out of the
        // gallery rather than shown twice. `fern` takes the laurel frond.
        case .oak: "leaf.fill"
        case .leaf: "leaf.fill"
        case .fern: "laurel.leading"
        case .flower: "camera.macro"
        case .waves: "water.waves"
        case .tower: "building.columns.fill"
        case .book: "book.closed.fill"
        case .key: "key.fill"
        case .hammer: "hammer.fill"
        case .compass: "location.north.circle.fill"
        case .sailboat: "sailboat.fill"
        case .crown: "crown.fill"
        case .horn: "horn.fill"
        case .crossedBanners: "flag.2.crossed.fill"
        }
    }
}

extension CrestFinish: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .flat: "Flat"
        case .sheen: "Sheen"
        case .embossed: "Embossed"
        }
    }
}

extension CrestDepth: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .none: "None"
        case .soft: "Soft"
        case .lifted: "Lifted"
        }
    }
}

extension CrestChargeWeight: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .light: "Light"
        case .regular: "Regular"
        case .bold: "Bold"
        }
    }
}

extension CrestMonogramStyle: BrowserSpaceHeraldicTerm {
    var title: String {
        switch self {
        case .serif: "Serif"
        case .sans: "Sans"
        }
    }
}
