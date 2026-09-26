namespace CrestCore.Contracts;

/// The Crest browser-data file is of `Version`, a format this build cannot read.
public sealed record UnsupportedArchiveVersion(int Version) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized(Argument = nameof(Version))]
    public string Message => "This Crest browser-data version (%lld) is not supported.";

    #endregion
}
