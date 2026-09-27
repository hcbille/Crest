using CrestCore.Application;
using CrestCore.Domain;

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
    IReadOnlyList<string> Remote) : Query<PaletteAnswer> {
    #region Variables

    /// Only reading what the window shows holds the lock; ranking reads immutable records outside it.
    internal override bool AnsweredUnderLock => false;

    #endregion

    #region Actions - Answering

    /// What a window's palette offers. Only reading what the window shows
    /// holds the lock; ranking reads immutable records outside it, so a
    /// palette answering on another thread never holds up the window.
    internal override PaletteAnswer Answer(CrestApp app) {
        Palette palette;
        lock (app.Gate) palette = app.Device.Palette(WindowId, app.Pages.OpensInternalPages);
        return palette.Answer(Text, Commands, Remote);
    }

    #endregion
}
