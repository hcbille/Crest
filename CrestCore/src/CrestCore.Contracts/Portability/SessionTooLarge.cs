namespace CrestCore.Contracts;

/// The browser's session file is larger than an import reads. Nothing was imported.
public sealed record SessionTooLarge : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This session file is larger than Crest’s 512 MB import limit.";

    #endregion
}
