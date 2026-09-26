namespace CrestCore.Contracts;

/// The browser's bookmark file is larger than an import reads. Nothing was imported.
public sealed record BookmarksTooLarge : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This bookmark file is larger than Crest’s 50 MB import limit.";

    #endregion
}
