namespace CrestCore.Contracts;

/// The browser's bookmarks hold no web page Crest can open. Nothing was imported.
public sealed record BookmarksHaveNoLinks : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This file does not contain any HTTP or HTTPS bookmarks Crest can import.";

    #endregion
}
