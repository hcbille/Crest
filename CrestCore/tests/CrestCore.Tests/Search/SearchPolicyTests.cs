using CrestCore.Application;
using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

public sealed class SearchPolicyTests {
    private const string KagiId = "00000000-0000-0000-0000-000000000264";

    /// A custom engine as a Space admits it.
    private static SearchProvider Kagi(string search, string? suggestions = null) =>
        SearchProvider.Admit(Guid.Parse(KagiId), "Kagi", search, suggestions);

    private static CustomSearchEngine Engine(string name, string template, Guid? id = null) =>
        new(id ?? Guid.Parse(KagiId), name, template, "  ");

    /// The engine as a Space saves it next to `existing`, through the rules
    /// the search-engine intents apply. Throws `Rejected` with the first rule
    /// it breaks.
    private static CustomSearchEngine Admitted(CustomSearchEngine engine, params CustomSearchEngine[] existing) {
        var provider = SearchProvider.Admit(engine.Id, engine.Name, engine.SearchTemplate, engine.SuggestionTemplate);
        SearchPreferences.Admit(provider, [.. existing.Select(other => (SearchProvider.CustomId(other.Id), other.Name))]);
        return new(engine.Id, provider.Title, provider.SearchTemplate, provider.SuggestionTemplate);
    }

    /// The rule admitting `engine` next to `existing` breaks, or null when it is admitted.
    private static Rejection? Refusal(CustomSearchEngine engine, params CustomSearchEngine[] existing) {
        try {
            Admitted(engine, existing);
            return null;
        } catch (Rejected rejected) {
            return rejected.Rejection;
        }
    }

    [Theory]
    [InlineData("native mac browser", "native%20mac%20browser")]
    [InlineData("a+b", "a%2Bb")]
    [InlineData("fish & chips=good", "fish%20%26%20chips%3Dgood")]
    [InlineData("C# #tag", "C%23%20%23tag")]
    [InlineData("Café 日本", "Caf%C3%A9%20%E6%97%A5%E6%9C%AC")]
    [InlineData("🦊", "%F0%9F%A6%8A")]
    [InlineData("a/b?c", "a%2Fb%3Fc")]
    [InlineData("-._~", "-._~")]
    [InlineData("%s {searchTerms}", "%25s%20%7BsearchTerms%7D")]
    [InlineData("100%", "100%25")]
    [InlineData("", "")]
    public void QueriesArePercentEncodedOnceAsUtf8IntoTheSinglePlaceholder(string query, string encoded) {
        Assert.Equal("https://www.google.com/search?q=" + encoded, SearchProvider.Google.Search(query));
        Assert.Equal("https://kagi.com/find/" + encoded + "?source=crest", Kagi("https://kagi.com/find/{searchTerms}?source=crest").Search(query));
    }

    [Fact]
    public void TheBuiltInCatalogOwnsEveryEnginesResultsAndSuggestionTemplates() {
        var expected = new Dictionary<string, (string Search, string Suggestions)> {
            ["google"] = ("https://www.google.com/search?q=a%20b", "https://www.google.com/complete/search?client=chrome&q=a%20b"),
            ["duckDuckGo"] = ("https://duckduckgo.com/?q=a%20b", "https://duckduckgo.com/ac/?q=a%20b&type=list"),
            ["bing"] = ("https://www.bing.com/search?q=a%20b", "https://www.bing.com/osjson.aspx?query=a%20b"),
            ["ecosia"] = ("https://www.ecosia.org/search?q=a%20b", "https://ac.ecosia.org/autocomplete?q=a%20b&type=list"),
            ["brave"] = ("https://search.brave.com/search?q=a%20b", "https://search.brave.com/api/suggest?q=a%20b")
        };
        Assert.Equal(expected.Keys, SearchProvider.All.Select(p => p.Name));
        foreach (var (id, urls) in expected) {
            Assert.Equal(urls.Search, SearchProvider.Named(id)!.Search("a b"));
            Assert.Equal(urls.Suggestions, SearchProvider.Named(id)!.Suggest("a b"));
        }
    }

    [Fact]
    public void CustomEnginesBuildTheirOwnURLs() {
        Assert.Equal("https://kagi.com/api/autosuggest?q=crest%20browser",
            Kagi("https://kagi.com/search?q=%s", "https://kagi.com/api/autosuggest?q=%s").Suggest("crest browser"));
        Assert.Null(Kagi("https://kagi.com/search?q=%s").Suggest("crest"));
    }

    [Theory]
    [InlineData("https://example.com/search?q=%s", "Example", null)]
    [InlineData("  https://example.com/search?q=%s  ", "  Example  ", null)]
    [InlineData("https://example.com:443/search/%s", "Example", null)]
    [InlineData("https://example.com/search?q=%s", "   ", "emptyName")]
    [InlineData("https://example.com/search?q=%s", "12345678901234567890123456789012345678901234567890123456789012345", "nameTooLong")]
    [InlineData("https://example.com/search", "Example", "missingPlaceholder")]
    [InlineData("https://example.com/?q=%s&again=%s", "Example", "ambiguousPlaceholder")]
    [InlineData("https://example.com/?q=%s&again={searchTerms}", "Example", "ambiguousPlaceholder")]
    [InlineData("https://example.com/?q=%s&bad=%zz", "Example", "invalidTemplate")]
    [InlineData("http://example.com/?q=%s", "Example", "requiresHttps")]
    [InlineData("example.com/?q=%s", "Example", "requiresHttps")]
    [InlineData("https://user:password@example.com/?q=%s", "Example", "credentialsInTemplate")]
    [InlineData("https://example.com:8443/?q=%s", "Example", "nonstandardPort")]
    [InlineData("https://%s.example.com/search", "Example", "unsafeHost")]
    [InlineData("https://localhost/search?q=%s", "Example", "unsafeHost")]
    [InlineData("https://printer.local/search?q=%s", "Example", "unsafeHost")]
    [InlineData("https://192.168.1.1/search?q=%s", "Example", "unsafeHost")]
    [InlineData("https://example.com/search#q=%s", "Example", "placeholderInFragment")]
    [InlineData("https://example.com/search?Token=secret&q=%s", "Example", "secretInTemplate")]
    [InlineData("https://example.com/search?api%5Fkey=secret&q=%s", "Example", "secretInTemplate")]
    public void CustomEngineValidationNamesTheRuleThePersonBroke(string template, string name, string? flaw) {
        var engine = Engine(name, template);
        Assert.Equal(SearchEngineFlaw.Named(flaw) is { } expected ? new InvalidSearchEngine(expected) : null, Refusal(engine));
        if (flaw is null) {
            var admitted = Admitted(engine);
            Assert.Equal(new CustomSearchEngine(engine.Id, "Example", template.Trim(), null), admitted);
        }
    }

    [Fact]
    public void AdmissionRejectsFoldedDuplicateNamesAndTheThirtyThirdEngine() {
        var engine = Engine("Café", "https://example.org/?q=%s");
        Assert.Equal(new DuplicateSearchEngineName(), Refusal(engine, Engine("  CAFE ", "https://a.example/?q=%s", Guid.NewGuid())));
        Assert.Equal(new InvalidSearchEngine(SearchEngineFlaw.TemplateTooLong),
            Refusal(Engine("Long", "https://example.com/?q=%s&p=" + new string('a', 2048))));
        // Editing an engine may keep its own name.
        Assert.Null(Refusal(engine, engine));
        var full = Enumerable.Range(0, 32).Select(i => Engine($"Engine {i}", "https://a.example/?q=%s", Guid.NewGuid())).ToArray();
        Assert.Equal(new SearchEngineLimitReached(SearchPreferences.MaximumCustomProviders), Refusal(engine, full));
        full[5] = engine with { Name = "Engine 5" };
        Assert.Null(Refusal(engine, full));
    }

    [Fact]
    public void StoredEnginesRestoreWithoutInvalidOrDuplicateEntriesAndKeepASafeSelection() {
        var valid = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var invalid = Guid.Parse("00000000-0000-0000-0000-000000000002");
        SearchPreferences Restore(BuiltInSearchEngine? builtIn, Guid? custom) => SearchPreferences.Restore(new BrowsingPreferences(
            builtIn, custom, [new(invalid, "Engine 2", "http://127.0.0.1/?q=%s", null), new(valid, "Engine 1", "https://a.example/?q=%s", null),
                new(valid, "Engine 1", "https://b.example/?q=%s", null)],
            SearchSuggestionsEnabled: false, CurrentTabCleanup.Never, ContentBlockingPolicy.Balanced,
            new(DataRetention.Forever, DataRetention.Forever, DataRetention.Forever)));
        var restored = Restore(null, invalid);
        Assert.Equal([SearchProvider.CustomId(valid)], restored.CustomProviders.Select(provider => provider.Name));
        Assert.Equal("https://a.example/?q=a", restored.CustomProviders[0].Search("a"));
        Assert.Equal("google", restored.SelectedId);
        Assert.Equal(SearchProvider.CustomId(valid), Restore(null, valid).SelectedId);
        Assert.Equal("brave", Restore(BuiltInSearchEngine.Brave, null).SelectedId);
    }
}
