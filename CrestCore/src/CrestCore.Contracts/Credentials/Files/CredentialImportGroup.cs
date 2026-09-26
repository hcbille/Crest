namespace CrestCore.Contracts;

/// One account an import brings: its site, the username its first row
/// spells, each distinct password its rows offer, how many rows only repeat
/// one of them, the saved password it would change, if any, and the row the
/// import proposes, or null to keep the saved password.
[HoldsSecrets]
public sealed record CredentialImportGroup(CredentialOrigin Origin, string Username, IReadOnlyList<CredentialImportCandidate> Candidates,
    int CollapsedDuplicateRowCount, Guid? ExistingId, int? SuggestedRow) {
    #region Variables

    /// Whether the person must choose: the file offers several passwords, or
    /// one that differs from the saved password.
    [Resolved]
    public bool RequiresChoice => Candidates.Count > 1
        || ExistingId is not null && !(Candidates.Count == 1 && Candidates[0].Effect == CredentialImportEffect.Matches);

    #endregion

    #region Actions - Text

    public override string ToString() {
        var text = new System.Text.StringBuilder("CredentialImportGroup { ");
        PrintMembers(text);
        return text.Append(" }").ToString();
    }

    /// The members that name no secret.
    private bool PrintMembers(System.Text.StringBuilder builder) {
        builder.Append($"Origin = {Origin}, Username = <redacted>, Candidates = {Candidates.Count}, ExistingId = {ExistingId}");
        return true;
    }

    #endregion
}
