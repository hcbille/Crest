namespace CrestCore.Contracts;

/// Setup is reading or importing a browser, so what it works on cannot change.
public sealed record SetupBusy : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Wait for setup to finish reading or importing.";

    #endregion
}
