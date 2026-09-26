namespace CrestCore.Contracts;

/// A command the palette may offer, with the title and section title the
/// platform shows for it, which ranking matches what a person types against.
public sealed record PaletteCommand(ShortcutCommand Command, string Title, string SectionTitle);
