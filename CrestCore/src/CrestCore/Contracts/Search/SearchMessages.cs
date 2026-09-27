namespace CrestCore.Contracts;

#region Queries

/// The address typed input loads, or null when it names nothing a page can
/// load. `SearchQuery` is the text searched for when the address is a search.
public sealed record ResolvedAddress(string? Url, string? SearchQuery);

/// The results address of a selection search, or null when the selection is
/// blank or the address is one Crest does not open, and the title of the
/// engine that runs it.
public sealed record SelectionSearchAnswer(string? Url, string EngineTitle);

#endregion

#region Rejections

/// Another custom engine in the Space already uses this name, ignoring case and
/// diacritics.
public sealed record DuplicateSearchEngineName() : Rejection {
    #region Variables

    /// What the engine editor tells the person.
    [Localized]
    public string Message => "A custom search engine already uses this name.";

    #endregion
}

/// A custom search engine has `Flaw`, the first rule it breaks.
public sealed record InvalidSearchEngine(SearchEngineFlaw Flaw) : Rejection;

/// The Space already holds `Limit` custom search engines.
public sealed record SearchEngineLimitReached(int Limit) : Rejection {
    #region Variables

    /// What the engine editor tells the person.
    [Localized(Argument = nameof(Limit))]
    public string Message => "A Space can contain up to %lld custom search engines.";

    #endregion
}

#endregion

#region Models

/// A Space's custom search engine as the person typed it or as it is stored.
/// Each template holds exactly one `%s` or `{searchTerms}` query placeholder;
/// an absent suggestion template means the engine offers no suggestions.
public sealed record CustomSearchEngine(Guid Id, string Name, string SearchTemplate, string? SuggestionTemplate);

#endregion
