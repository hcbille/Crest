namespace CrestCore.Contracts;

/// A password the Space already keeps, which an import is compared against.
/// Only a web form's password stands for an account a file imports. Dates are
/// in seconds since 1970.
[HoldsSecrets]
public sealed record ExistingCredential(Guid Id, CredentialOrigin Origin, string Username, bool IsWebForm, double UpdatedAt,
    double? LastUsedAt, string Password) {
    #region Actions - Text

    public override string ToString() {
        var text = new System.Text.StringBuilder("ExistingCredential { ");
        PrintMembers(text);
        return text.Append(" }").ToString();
    }

    /// The members that name no secret.
    private bool PrintMembers(System.Text.StringBuilder builder) {
        builder.Append($"Id = {Id}, Origin = {Origin}, Username = <redacted>, IsWebForm = {IsWebForm}, Password = <redacted>");
        return true;
    }

    #endregion
}
