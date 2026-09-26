using System.Globalization;

using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// What importing passwords into a Space means, against the passwords it
/// keeps. Rows for one account, the same site and a username that differs at
/// most in case, form one group; a group offers each distinct password once,
/// in row order, and a password the Space keeps for the account, its most
/// recent web form password, is the one the group would change. A group the
/// Space keeps a password for proposes keeping it; any other proposes its
/// first row. Groups run in order of site, then username.
internal static class CredentialImportPlanning {
    #region Static Variables

    /// Compares usernames as one account: ignoring case.
    private static readonly StringComparer Usernames = StringComparer.InvariantCultureIgnoreCase;

    #endregion

    #region Actions - Planning

    /// The plan for `credentials`, read as `format` with `rejections` already
    /// left out, against `existing`. A credential whose site is no web
    /// address, or whose password is empty, is left out too.
    public static CredentialImportPlan Plan(CredentialFileFormat format, IReadOnlyList<ImportedCredential> credentials,
        IReadOnlyList<CredentialRowRejection> rejections, IReadOnlyList<ExistingCredential> existing) {
        ArgumentNullException.ThrowIfNull(format);
        ArgumentNullException.ThrowIfNull(credentials);
        ArgumentNullException.ThrowIfNull(rejections);
        ArgumentNullException.ThrowIfNull(existing);
        if (existing.Select(saved => saved.Id).Distinct().Count() != existing.Count) throw new Rejected(new DuplicateCredential());
        var left = rejections.ToList();
        var valid = new List<ImportedCredential>(credentials.Count);
        foreach (var credential in credentials) {
            if (!credential.Origin.IsValid) left.Add(new(credential.RowNumber, CredentialRowFlaw.InvalidOrigin));
            else if (credential.Password.Length == 0) left.Add(new(credential.RowNumber, CredentialRowFlaw.EmptyPassword));
            else valid.Add(credential);
        }
        var saved = existing.Where(credential => credential.IsWebForm).ToLookup(credential => Account(credential.Origin,
            credential.Username));
        var groups = valid.GroupBy(credential => Account(credential.Origin, credential.Username))
            .Select(rows => Group([.. rows.OrderBy(row => row.RowNumber)], MostRecent(saved[rows.Key])))
            .OrderBy(group => group.Origin.Spelling, StringComparer.Ordinal)
            .ThenBy(group => group.Username, Usernames)
            .ToArray();
        var warnings = valid.Where(credential => !credential.Origin.IsSecure)
            .Select(credential => new CredentialRowWarning(credential.RowNumber, CredentialRowCaution.InsecureOrigin)).ToArray();
        return new(format, groups, [.. left.OrderBy(rejection => rejection.RowNumber)], warnings);
    }

    /// One account's group from its rows in order, against the password the
    /// Space keeps for it, if any.
    private static CredentialImportGroup Group(IReadOnlyList<ImportedCredential> rows, ExistingCredential? existing) {
        var candidates = new List<CredentialImportCandidate>();
        foreach (var row in rows) {
            if (candidates.Any(candidate => candidate.Password == row.Password)) continue;
            var effect = existing is null ? CredentialImportEffect.Adds
                : existing.Password == row.Password ? CredentialImportEffect.Matches : CredentialImportEffect.Replaces;
            candidates.Add(new(row.RowNumber, row.Username, row.DisplayName, row.Password, effect));
        }
        return new(rows[0].Origin, rows[0].Username, candidates, rows.Count - candidates.Count, existing?.Id,
            existing is null ? candidates[0].RowNumber : null);
    }

    /// The most recent of the passwords the Space keeps for one account, or
    /// null when it keeps none.
    private static ExistingCredential? MostRecent(IEnumerable<ExistingCredential> saved) {
        ExistingCredential? best = null;
        foreach (var credential in saved) {
            if (!double.IsFinite(credential.UpdatedAt) || credential.LastUsedAt is { } used && !double.IsFinite(used))
                throw new Rejected(new InvalidCredentialDate());
            if (best is null || CredentialRecencyPolicy.IsLessRecent(Record(best), Record(credential))) best = credential;
        }
        return best;
    }

    private static CredentialRecord Record(ExistingCredential credential) =>
        new(credential.Id, Username: null, credential.UpdatedAt, credential.LastUsedAt);

    /// The key an account's rows share: its site and its username in one case.
    private static (CredentialOrigin Origin, string Username) Account(CredentialOrigin origin, string username) =>
        (origin, username.ToUpper(CultureInfo.InvariantCulture).ToLower(CultureInfo.InvariantCulture));

    #endregion
}
