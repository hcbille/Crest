namespace CrestCore.Domain;

/// A known address that completes what was typed: the text completing it
/// leaves, and how closely it matches, from a host that merely starts with
/// what was typed to a typed path.
public sealed record AddressMatch(AddressCandidate Candidate, string Text, int Quality) {
    #region Actions - Ranking

    /// Whether this completion ranks above `other`: a closer match, then a
    /// better source, a later date, more visits, and then the earlier text
    /// and address, so the order never depends on where a candidate was found.
    public bool Outranks(AddressMatch other) {
        ArgumentNullException.ThrowIfNull(other);
        if (Quality != other.Quality) return Quality > other.Quality;
        if (Candidate.Source != other.Candidate.Source) return Candidate.Source > other.Candidate.Source;
        if (Candidate.Date != other.Candidate.Date) return Candidate.Date > other.Candidate.Date;
        if (Candidate.Visits != other.Candidate.Visits) return Candidate.Visits > other.Candidate.Visits;
        int text = string.CompareOrdinal(Text, other.Text);
        if (text != 0) return text < 0;
        return string.CompareOrdinal(Candidate.Url, other.Candidate.Url) < 0;
    }

    #endregion
}
