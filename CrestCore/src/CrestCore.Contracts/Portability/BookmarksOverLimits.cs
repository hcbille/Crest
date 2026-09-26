namespace CrestCore.Contracts;

/// The browser's bookmarks hold more folders, nesting, tabs or Spaces than Crest keeps. Nothing was imported.
public sealed record BookmarksOverLimits : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This bookmark file exceeds Crest’s folder, depth, tab, or Space limits.";

    #endregion
}
