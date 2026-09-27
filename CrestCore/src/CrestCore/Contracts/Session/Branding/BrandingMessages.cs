namespace CrestCore.Contracts;

#region Queries

/// Branding as a Space keeps it once the core's range rules apply.
public sealed record NormalizedBranding(SpaceBranding Branding);

#endregion

#region Models - Crests

/// <summary>The shape a crest is drawn on.</summary>
public enum CrestBackplate {
    None,
    Circle,
    Shield,
    FrenchShield,
    Diamond,
    Seal,
    Hexagon,
    Octagon,
    RoundedSquare,
    Oval,
    Banner,
    Badge
}

/// <summary>
/// A crest's custom figure: a heraldic <see cref="Symbol"/>, or <see cref="Text"/> naming
/// a system symbol, an emoji or the letters of a monogram in its <see cref="Style"/>.
/// </summary>
public sealed record CrestCharge(CrestChargeKind Kind, CrestSymbol? Symbol = null, string? Text = null,
    CrestMonogramStyle? Style = null);

/// <summary>What a crest's custom figure is drawn from.</summary>
public enum CrestChargeKind { Heraldic, System, Emoji, Monogram, None }

/// <summary>The letterforms of a monogram charge.</summary>
public enum CrestMonogramStyle {
    Serif,
    Sans
}

/// <summary>How many figures a crest repeats, and how.</summary>
public enum CrestChargeLayout {
    Single,
    Paired,
    Trio,
    Quad,
    Ring
}

/// <summary>The stroke weight of a crest's figure.</summary>
public enum CrestChargeWeight {
    Light,
    Regular,
    Bold
}

/// <summary>How far a crest stands off the banner.</summary>
public enum CrestDepth {
    None,
    Soft,
    Lifted
}

/// <summary>How a crest's field is divided.</summary>
public enum CrestFieldDivision {
    Plain,
    PerPale,
    PerFess,
    PerBend,
    PerChevron,
    Quarterly,
    PerSaltire,
    Gyronny,
    Barry,
    Paly,
    Checky
}

/// <summary>The surface a crest is rendered with.</summary>
public enum CrestFinish {
    Flat,
    Sheen,
    Embossed
}

/// <summary>The band or cross laid over a crest's field.</summary>
public enum CrestOrdinary {
    None,
    Pale,
    Fess,
    Bend,
    Chevron,
    Cross,
    Saltire,
    Chief,
    Bordure,
    Pall,
    Pile,
    Canton,
    Roundel
}

/// <summary>A heraldic figure a crest can carry.</summary>
public enum CrestSymbol {
    Dragon,
    Direwolf,
    Lion,
    Stag,
    Raven,
    Griffin,
    Eagle,
    Bear,
    Boar,
    Fox,
    Horse,
    Unicorn,
    Wyvern,
    Hydra,
    Serpent,
    Kraken,
    Seahorse,
    Scorpion,
    Bat,
    Falcon,
    Rose,
    Lily,
    Pine,
    Willow,
    Swords,
    Axes,
    Sword,
    Trident,
    Anchor,
    Castle,
    Scales,
    DragonHead,
    Hound,
    Paw,
    Hare,
    Bird,
    Fish,
    Bee,
    Shell,
    Sun,
    RisingSun,
    Crescent,
    Star,
    Sparkles,
    Lightning,
    Flame,
    Snowflake,
    Drop,
    Mountain,
    Tree,
    Oak,
    Leaf,
    Fern,
    Flower,
    Waves,
    Tower,
    Book,
    Key,
    Hammer,
    Compass,
    Sailboat,
    Crown,
    Horn,
    CrossedBanners
}

/// <summary>The border drawn around a crest.</summary>
public enum CrestTrim {
    None,
    Shield,
    Line,
    DoubleLine,
    Laurel,
    Sunburst,
    DoubleRing,
    Seal,
    Beaded
}

#endregion

#region Models - Space Look

/// <summary>How a Space's banner arranges its colors.</summary>
public enum SpaceBannerPattern {
    Solid,
    Split,
    Bands,
    Diagonal,
    Chevron,
    Quartered,
    Stripes,
    Checkered,
    Lozenges
}

/// <summary>Whether a Space's icon is a plain symbol or its layered crest.</summary>
public enum SpaceIconStyle {
    SimpleSymbol,
    LayeredCrest
}

/// <summary>Whether sidebar text follows the banner or stays light or dark.</summary>
public enum SpaceTextColorMode {
    Automatic,
    Light,
    Dark
}

/// <summary>Whether a Space's sidebar wears its banner or a gradient.</summary>
public enum SpaceThemeMode {
    Banner,
    Gradient
}

#endregion
