namespace CrestCore.Contracts;

/// The browser's session holds more Spaces, tabs, folders or text than a Space keeps. Nothing was imported.
public sealed record SessionOverLimits : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This session exceeds Crest’s Space, tab, folder, or text limits.";

    #endregion
}
