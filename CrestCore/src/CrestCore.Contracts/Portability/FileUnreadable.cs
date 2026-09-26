namespace CrestCore.Contracts;

/// The file could not be read. Nothing was imported.
public sealed record FileUnreadable : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest could not read this file.";

    #endregion
}
