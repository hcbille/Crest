namespace CrestCore.Contracts;

/// For each candidate, in order, whether it names the asked language.
public sealed record LanguageMatches(IReadOnlyList<bool> Matches);
