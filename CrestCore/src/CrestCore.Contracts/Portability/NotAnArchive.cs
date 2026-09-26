namespace CrestCore.Contracts;

/// The file is not Crest browser data. Nothing was imported.
public sealed record NotAnArchive : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This is not a Crest browser-data file.";

    #endregion
}
