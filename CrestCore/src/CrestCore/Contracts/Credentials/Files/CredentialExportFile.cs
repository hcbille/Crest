namespace CrestCore.Contracts;

/// A password file to save as `FileName`.
[HoldsSecrets]
public sealed record CredentialExportFile(string FileName, byte[] Contents) {
    #region Actions - Text

    public override string ToString() {
        var text = new System.Text.StringBuilder("CredentialExportFile { ");
        PrintMembers(text);
        return text.Append(" }").ToString();
    }

    /// The members that name no secret.
    private bool PrintMembers(System.Text.StringBuilder builder) {
        builder.Append($"FileName = {FileName}, Contents = <{Contents.Length} bytes redacted>");
        return true;
    }

    #endregion
}
