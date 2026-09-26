namespace CrestCore.Contracts;

/// Rows of one section of the palette, in the order it ranked them.
public sealed record PaletteGroup(PaletteSection Section, IReadOnlyList<PaletteRow> Rows);
