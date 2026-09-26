namespace CrestCore.Contracts;

/// Whether each of `Candidates` names the same translation language as
/// `Language`. It reads no state, so a host may ask it without an app.
public sealed record LanguagesMatching(string Language, IReadOnlyList<string> Candidates) : Query<LanguageMatches>;
