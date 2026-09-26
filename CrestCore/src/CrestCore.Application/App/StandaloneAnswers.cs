using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The queries that read no state: whether two addresses name one page, the
/// addresses history keeps for others, how
/// translation languages match, which translation rule applies, and what an
/// address typed outside any workspace loads. A host
/// asks them before it has an app, or from code that holds none; an app
/// answers them the same way.
public sealed class StandaloneAnswers : IQueryAnswers {
    #region Actions - Queries

    public TAnswer Query<TAnswer>(Query<TAnswer> query) {
        ArgumentNullException.ThrowIfNull(query);
        return (TAnswer)Answer(query);
    }

    /// The answer to a query that reads no state. Throws for any other.
    internal static object Answer(object query) => query switch {
        SamePage pages => new PageMatch(new WebAddress(pages.First).IsSamePage(new WebAddress(pages.Second))),
        HistoryAddresses addresses => new HistoryAddressList([.. addresses.Addresses.Select(address => new WebAddress(address).Normalized)]),
        LanguagesMatching matching => new LanguageMatches([.. matching.Candidates.Select(candidate =>
            LanguageTag.Matches(matching.Language, candidate))]),
        TranslationChoice choice => Decided(choice),
        ResolveAddress { WorkspaceId: null } address => NativeSessionAuthority.Resolved(address.Input, SearchProvider.Google,
            allowsInternalPages: false),
        _ => throw new ArgumentOutOfRangeException(nameof(query), query.GetType().Name, "No area answers this query.")
    };

    private static TranslationDecision Decided(TranslationChoice choice) {
        var rules = AutomaticTranslationRules.Restore(choice.Rules);
        return new(rules.Rule(choice.SourceLanguage), rules.Target(choice.SourceLanguage));
    }

    #endregion
}
