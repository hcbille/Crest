namespace CrestCore.Contracts;

/// Setup is not open on this device.
public sealed record NoSetup : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Setup is no longer open. Open it again.";

    #endregion
}
