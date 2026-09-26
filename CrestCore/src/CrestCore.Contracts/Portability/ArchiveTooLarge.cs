namespace CrestCore.Contracts;

/// The Crest browser-data file is larger than an import reads. Nothing was imported.
public sealed record ArchiveTooLarge : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This file is larger than Crest’s 50 MB import limit.";

    #endregion
}
