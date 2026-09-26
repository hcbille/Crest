namespace CrestCore.Contracts;

/// What a window's command palette offers for `Text`: an address to open or a
/// search to run, the window's tabs, the `Commands` the platform offers there,
/// the Space's pinned and saved tabs and folders, and its history, each group
/// ranked, with an address completion for the text. `Remote` holds the search
/// suggestions the platform fetched from `PaletteAnswer.SuggestionAddress` for
/// the same text, which join the answer under the address or search, or is
/// empty. The palette speaks for the Space the window shows and leaves out the
/// tab it shows; a locked Space offers none of its tabs or history.
public sealed record PaletteSuggestions(Guid WindowId, string Text, IReadOnlyList<PaletteCommand> Commands,
    IReadOnlyList<string> Remote) : Query<PaletteAnswer>;
