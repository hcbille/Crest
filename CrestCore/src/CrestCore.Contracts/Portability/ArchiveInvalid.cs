namespace CrestCore.Contracts;

/// The Crest browser-data file holds something Crest would not keep. Nothing was imported.
public sealed record ArchiveInvalid : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This file does not contain valid Crest browser data.";

    #endregion
}
