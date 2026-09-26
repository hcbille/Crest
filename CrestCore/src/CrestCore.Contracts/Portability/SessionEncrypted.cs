namespace CrestCore.Contracts;

/// The Chromium session is encrypted with its profile's key, which only that browser holds. Nothing was imported.
public sealed record SessionEncrypted : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "This Chromium session is profile-encrypted and cannot be safely imported outside its source browser.";

    #endregion
}
