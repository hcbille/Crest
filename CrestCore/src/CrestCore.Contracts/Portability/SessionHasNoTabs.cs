namespace CrestCore.Contracts;

/// The browser's session holds no web page Crest can open. Nothing was imported.
public sealed record SessionHasNoTabs : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This session has no HTTP or HTTPS tabs Crest can import.";

    #endregion
}
