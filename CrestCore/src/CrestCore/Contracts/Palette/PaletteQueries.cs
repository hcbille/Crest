namespace CrestCore.Contracts;

/// The palette's rows, in the groups it shows them, first to last. The first
/// row is what Return activates. `Completion` completes the text as an address
/// the Space already knows, or is null. `SuggestionAddress` is where the
/// platform may fetch search suggestions for the text, or null when the window
/// is private, the Space does not offer them, or its search engine has none.
public sealed record PaletteAnswer(IReadOnlyList<PaletteGroup> Groups, AddressCompletion? Completion, string? SuggestionAddress);

/// Completes what a person typed, `Typed`, as an address the Space already
/// knows: `Suffix` follows the text as typed, and accepting the completion
/// leaves `Accepted`, which adds the scheme when the address is not https.
public sealed record AddressCompletion(string Typed, string Suffix, string Accepted);

/// Rows of one section of the palette, in the order it ranked them.
public sealed record PaletteGroup(PaletteSection Section, IReadOnlyList<PaletteRow> Rows);

/// One thing the palette offers. Activating it shows `TabId`, opens `Address`
/// or performs `Command`, whichever it names. `SubjectId` is what the row
/// stands for when that is not its target: the folder a folder row opens the
/// first tab of, or a history entry. A search row names its engine in
/// `Engine` or `CustomEngineId`. `Symbol` is the SF Symbol the row wears when
/// no tab icon or engine logo stands for it.
public sealed record PaletteRow(PaletteRowKind Kind, string Title, string Subtitle, string Symbol, Guid? SubjectId, Guid? TabId,
    string? Address, ShortcutCommand? Command, BuiltInSearchEngine? Engine, Guid? CustomEngineId);

/// A command the palette may offer, with the title and section title the
/// platform shows for it, which ranking matches what a person types against.
public sealed record PaletteCommand(ShortcutCommand Command, string Title, string SectionTitle);
