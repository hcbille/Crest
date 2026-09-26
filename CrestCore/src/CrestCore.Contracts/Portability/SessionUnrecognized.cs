namespace CrestCore.Contracts;

/// The browser's session file holds nothing Crest recognizes as its tabs. Nothing was imported.
public sealed record SessionUnrecognized : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest could not recognize this browser’s tab-session data.";

    #endregion
}
