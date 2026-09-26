namespace CrestCore.Contracts;

/// The browser's bookmark file holds nothing Crest recognizes as bookmarks. Nothing was imported.
public sealed record BookmarksUnrecognized : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest could not recognize this browser’s bookmark data.";

    #endregion
}
