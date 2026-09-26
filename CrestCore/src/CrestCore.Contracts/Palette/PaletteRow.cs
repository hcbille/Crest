namespace CrestCore.Contracts;

/// One thing the palette offers. Activating it shows `TabId`, opens `Address`
/// or performs `Command`, whichever it names. `SubjectId` is what the row
/// stands for when that is not its target: the folder a folder row opens the
/// first tab of, or a history entry. A search row names its engine in
/// `Engine` or `CustomEngineId`. `Symbol` is the SF Symbol the row wears when
/// no tab icon or engine logo stands for it.
public sealed record PaletteRow(PaletteRowKind Kind, string Title, string Subtitle, string Symbol, Guid? SubjectId, Guid? TabId,
    string? Address, ShortcutCommand? Command, BuiltInSearchEngine? Engine, Guid? CustomEngineId);
