namespace CrestCore.Contracts;

/// What importing a password file, or another browser's passwords, into a
/// Space means: the file's format, each account it brings in order of site
/// and username, the rows it leaves out and the rows it warns about.
[HoldsSecrets]
public sealed record CredentialImportPlan(CredentialFileFormat Format, IReadOnlyList<CredentialImportGroup> Groups,
    IReadOnlyList<CredentialRowRejection> Rejections, IReadOnlyList<CredentialRowWarning> Warnings) {
    #region Variables

    /// How many of the file's rows import or repeat a password that does.
    [Resolved]
    public int ValidRowCount => Groups.Sum(group => group.Candidates.Count + group.CollapsedDuplicateRowCount);

    #endregion

    #region Actions - Text

    public override string ToString() {
        var text = new System.Text.StringBuilder("CredentialImportPlan { ");
        PrintMembers(text);
        return text.Append(" }").ToString();
    }

    /// The members that name no secret.
    private bool PrintMembers(System.Text.StringBuilder builder) {
        builder.Append($"Format = {Format.Name}, Groups = {Groups.Count}, Rejections = {Rejections.Count}, Warnings = {Warnings.Count}");
        return true;
    }

    #endregion
}
