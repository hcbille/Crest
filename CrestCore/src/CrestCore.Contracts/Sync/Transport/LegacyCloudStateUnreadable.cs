namespace CrestCore.Contracts;

/// The cloud transport state an installed release kept does not read. Nothing
/// was adopted.
public sealed record LegacyCloudStateUnreadable : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest couldn’t read the iCloud sync state an earlier version saved.";

    #endregion
}
