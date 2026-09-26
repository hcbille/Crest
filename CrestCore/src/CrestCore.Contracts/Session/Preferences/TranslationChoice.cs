namespace CrestCore.Contracts;

/// The rule among `Rules` that applies to pages in `SourceLanguage`, whose
/// region aliases share it, and the language such pages are translated into.
/// It reads no state, so a host may ask it without an app.
public sealed record TranslationChoice(IReadOnlyList<TranslationRule> Rules, string SourceLanguage) : Query<TranslationDecision>;
