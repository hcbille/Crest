namespace CrestCore.Contracts;

/// No manual setup is in progress on this device for the workspace.
public sealed record NoManualSetup : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Setup is no longer in progress. Start it again.";

    #endregion
}
