using System.Text;
using System.Text.Json.Nodes;

using CrestCore.Application;
using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

public sealed class NativePolicyTests {
    private static SearchProvider Kagi() =>
        SearchProvider.Admit(Guid.Parse("00000000-0000-0000-0000-000000000264"), "Kagi", "https://kagi.com/search?q=%s", null);

    [Theory]
    [InlineData("apple.com", "https://apple.com", null)]
    [InlineData("localhost:3000", "http://localhost:3000", null)]
    [InlineData("https://webkit.org/blog/", "https://webkit.org/blog/", null)]
    [InlineData("  Café + Swift/URL & WebKit  ", "https://kagi.com/search?q=Caf%C3%A9%20%2B%20Swift%2FURL%20%26%20WebKit", "Café + Swift/URL & WebKit")]
    [InlineData("   ", null, null)]
    public void ExistingAddressCallSitesKeepTheirIntentAndURLSpelling(string input, string? url, string? query) {
        var resolved = AddressResolution.Resolve(input, Kagi());
        Assert.Equal(resolved, AddressResolution.Resolve(input, Kagi()));
        Assert.Equal(url, resolved?.Url);
        Assert.Equal(query, resolved?.SearchQuery);
    }
    [Theory]
    [InlineData("chrome://extensions/")]
    [InlineData("crest://extensions/?id=abcdefghijklmnopabcdefghijklmnop#details")]
    [InlineData("CREST://version/")]
    [InlineData("chrome-extension://abcdefghijklmnopabcdefghijklmnop/options.html")]
    public void InternalAddressesRequireTheSelectedEngineCapability(string address) {
        var disabled = AddressResolution.Resolve(address, Kagi(), allowsInternalPages: false)!;
        Assert.Equal(address, disabled.SearchQuery);
        var enabled = AddressResolution.Resolve(address, Kagi(), allowsInternalPages: true)!;
        Assert.Equal(address, enabled.Url);
        Assert.Null(enabled.SearchQuery);
    }
    [Theory]
    [InlineData("file:///Users/crest/Saved%20Page.webarchive", "file:///Users/crest/Saved%20Page.webarchive")]
    [InlineData("file://localhost/tmp/archive.mhtml", "file:///tmp/archive.mhtml")]
    [InlineData("/tmp/Saved Page.html", "file:///tmp/Saved%20Page.html")]
    [InlineData("file://example.com/tmp/page.html", null)]
    [InlineData("file:", null)]
    public void LocalDocumentAddressesResolveToFileURLsAndRemainValidTabURLs(string input, string? url) {
        var resolved = AddressResolution.Resolve(input, Kagi())!;
        if (url is null) {
            Assert.False(resolved.Url.StartsWith("file:", StringComparison.OrdinalIgnoreCase));
            Assert.Throws<BrowserRuleException>(() => BrowserSpace.ValidateUrl(input));
            return;
        }
        Assert.Equal(url, resolved.Url);
        Assert.Null(resolved.SearchQuery);
        BrowserSpace.ValidateUrl(url);
    }
    [Fact]
    public void HomeRelativeAddressesResolveAgainstThisDeviceOnly() {
        var resolved = AddressResolution.Resolve("~/Saved.webarchive", Kagi())!;
        Assert.StartsWith("file:///", resolved.Url);
        Assert.EndsWith("/Saved.webarchive", resolved.Url);
        Assert.Null(resolved.SearchQuery);
        Assert.Equal("~notapath", AddressResolution.Resolve("~notapath", Kagi())!.SearchQuery);
    }
    [Fact]
    public void CustomSearchTemplatesRejectCredentialAndLocalTargetsAndHaveStableSelectionFallback() {
        foreach (var template in new[] {
            "http://example.org/?q=%s", "https://example.org/?q=%s&token=secret", "https://localhost/?q=%s",
            "https://192.168.1.1/?q=%s", "https://%s.example.org/", "https://example.org/#%s",
            "https://example.org/?q=%s&other={searchTerms}", "https://example.org/?q=%s&bad=%z",
            "https://user:secret@example.org/?q=%s", "https://example.org:8443/?q=%s" })
            Assert.IsType<InvalidSearchEngine>(Assert.Throws<Rejected>(() =>
                SearchProvider.Admit(Guid.NewGuid(), "Custom", template, null)).Rejection);
        var id = Guid.NewGuid(); var provider = SearchProvider.Admit(id, "Café", "https://example.org/find/{searchTerms}", null);
        var preferences = SearchPreferences.Default.Add(provider).Select(provider);
        Assert.Equal("https://example.org/find/a%2Fb%3Fc", preferences.Resolve("a/b?c", false));
        Assert.IsType<DuplicateSearchEngineName>(Assert.Throws<Rejected>(() =>
            preferences.Add(SearchProvider.Admit(Guid.NewGuid(), "CAFE", "https://example.com/?q=%s", null))).Rejection);
        Assert.Equal("google", preferences.Remove(id).SelectedId);
        Assert.Equal(provider.Name, preferences.SelectedId);
        Assert.Throws<BrowserRuleException>(() => SearchPreferences.Default.Resolve("https://user:password@example.org", false));
    }

    [Fact]
    public void PurePolicyRejectsUnknownVersionsAndOperations() {
        Assert.Throws<ProtocolException>(() => NativePolicyEvaluator.Evaluate("{\"version\":2,\"operation\":\"address.intent\"}"u8));
        Assert.Throws<ProtocolException>(() => NativePolicyEvaluator.Evaluate("{\"version\":1,\"operation\":\"native.invoke\"}"u8));
        Assert.Throws<ProtocolException>(() => NativePolicyEvaluator.Evaluate(new byte[NativePolicyEvaluator.MaximumInputBytes + 1]));
    }
    [Fact]
    public void RetentionAndExplicitDeletionKeepTheirDifferentBoundaryRules() {
        // Retention excludes an exact cutoff and future records. Explicit
        // deletion includes its start and excludes its end.
        // The records commands (`records.sweep`, `history.remove_range`) apply
        // this rule; the stateless policy operations that exposed it are gone.
        Assert.Equal([0], RecordRemovalPolicy.Expired([9, 10, 11, 21], 20, 10));
        Assert.Equal([1, 2], RecordRemovalPolicy.WithinRange([9, 10, 11, 20], 10, 20));
        Assert.Empty(RecordRemovalPolicy.WithinRange([10], 20, 10));
    }
    [Theory]
    [InlineData("warning", "desktop", 8, 1)]
    [InlineData("critical", "desktop", 8, 4)]
    [InlineData("critical", "desktop", 7, 4)]
    [InlineData("critical", "desktop", 1, 1)]
    [InlineData("warning", "mobile", 8, 0)]
    [InlineData("critical", "mobile", 8, 1)]
    [InlineData("critical", "desktop", 0, 0)]
    [InlineData("warning", "desktop", 0, 0)]
    public void MemoryPressureBudgetsDifferByPlatformAndSeverity(string level, string platform, int eligible, int limit) {
        var request = new JsonObject {
            ["version"] = 1,
            ["operation"] = "residency.release_limit",
            ["level"] = level,
            ["platform"] = platform,
            ["eligiblePageCount"] = eligible
        };
        var response = JsonNode.Parse(NativePolicyEvaluator.Evaluate(Encoding.UTF8.GetBytes(request.ToJsonString())))!;
        Assert.Equal(limit, response["limit"]!.GetValue<int>());
        request["level"] = "moderate";
        Assert.Throws<ProtocolException>(() => NativePolicyEvaluator.Evaluate(Encoding.UTF8.GetBytes(request.ToJsonString())));
    }
    [Fact]
    public void ReleasePlanOrdersOffScreenPagesLeastRecentlyUsedAndExcludesHeldPages() {
        var plan = ReleasePlan("critical", "desktop", null,
            Candidate("00000000-0000-0000-0000-00000000000a", 30),
            Candidate("00000000-0000-0000-0000-00000000000b", 10),
            // Same idle stamp: tab identity decides, so a squeeze repeats.
            Candidate("00000000-0000-0000-0000-00000000000d", 20),
            Candidate("00000000-0000-0000-0000-00000000000c", 20),
            // Kept loaded by request, presented on screen, and a tab with no
            // page of its own. The first two are never candidates; the third
            // follows every stamped page.
            Candidate("00000000-0000-0000-0000-00000000000e", 1, keepsPageLoaded: true),
            Candidate("00000000-0000-0000-0000-00000000000f", 2, presentedIndex: 0),
            Candidate("00000000-0000-0000-0000-000000000010", null));
        Assert.Equal(new[] { "00000000-0000-0000-0000-00000000000b", "00000000-0000-0000-0000-00000000000c",
            "00000000-0000-0000-0000-00000000000d", "00000000-0000-0000-0000-00000000000a",
            "00000000-0000-0000-0000-000000000010" }, TabIds(plan, "tabIDs"));
        Assert.Empty(TabIds(plan, "fallbackTabIDs"));
    }
    [Fact]
    public void PresentedCardsOnlyFallBackUnderCriticalMobilePressureBeyondTheFocusedNeighbours() {
        JsonNode Plan(string level, string platform, int focused) => ReleasePlan(level, platform, focused,
            Candidate("00000000-0000-0000-0000-000000000101", 40, presentedIndex: 0),
            Candidate("00000000-0000-0000-0000-000000000102", 30, presentedIndex: 1),
            Candidate("00000000-0000-0000-0000-000000000103", 20, presentedIndex: 2),
            Candidate("00000000-0000-0000-0000-000000000104", 10, presentedIndex: 3));
        // Least recently used first, not carousel order.
        Assert.Equal(new[] { "00000000-0000-0000-0000-000000000104", "00000000-0000-0000-0000-000000000103" },
            TabIds(Plan("critical", "mobile", 0), "fallbackTabIDs"));
        Assert.Equal(new[] { "00000000-0000-0000-0000-000000000104" },
            TabIds(Plan("critical", "mobile", 1), "fallbackTabIDs"));
        Assert.Equal(new[] { "00000000-0000-0000-0000-000000000101" },
            TabIds(Plan("critical", "mobile", 2), "fallbackTabIDs"));
        Assert.Equal(new[] { "00000000-0000-0000-0000-000000000102", "00000000-0000-0000-0000-000000000101" },
            TabIds(Plan("critical", "mobile", 3), "fallbackTabIDs"));
        Assert.Empty(TabIds(Plan("warning", "mobile", 0), "fallbackTabIDs"));
        Assert.Empty(TabIds(Plan("critical", "desktop", 0), "fallbackTabIDs"));
        Assert.Empty(TabIds(Plan("critical", "mobile", 0), "tabIDs"));
    }
    [Fact]
    public void ReleasePlanRejectsInconsistentPresentationAndRepeatedTabs() {
        var duplicate = new JsonObject {
            ["version"] = 1,
            ["operation"] = "residency.release_plan",
            ["level"] = "critical",
            ["platform"] = "mobile",
            ["focusedIndex"] = null,
            ["candidates"] = new JsonArray(Candidate("00000000-0000-0000-0000-000000000201", 1),
                Candidate("00000000-0000-0000-0000-000000000201", 2))
        };
        Assert.Throws<BrowserRuleException>(() => NativePolicyEvaluator.Evaluate(Encoding.UTF8.GetBytes(duplicate.ToJsonString())));
        var presented = new JsonObject {
            ["version"] = 1,
            ["operation"] = "residency.release_plan",
            ["level"] = "critical",
            ["platform"] = "mobile",
            ["focusedIndex"] = 0,
            ["candidates"] = new JsonArray(new JsonObject {
                ["tabID"] = "00000000-0000-0000-0000-000000000202",
                ["inactiveSince"] = 1,
                ["isPresented"] = true,
                ["presentedIndex"] = null
            })
        };
        Assert.Throws<BrowserRuleException>(() => NativePolicyEvaluator.Evaluate(Encoding.UTF8.GetBytes(presented.ToJsonString())));
    }
    private static JsonObject Candidate(string tabId, double? inactiveSince,
        bool keepsPageLoaded = false, int? presentedIndex = null) => new() {
            ["tabID"] = tabId,
            ["inactiveSince"] = inactiveSince,
            ["keepsPageLoaded"] = keepsPageLoaded,
            ["isPresented"] = presentedIndex.HasValue,
            ["presentedIndex"] = presentedIndex
        };
    private static JsonNode ReleasePlan(string level, string platform, int? focusedIndex, params JsonObject[] candidates) {
        var request = new JsonObject {
            ["version"] = 1,
            ["operation"] = "residency.release_plan",
            ["level"] = level,
            ["platform"] = platform,
            ["focusedIndex"] = focusedIndex,
            ["candidates"] = new JsonArray(candidates.Select(candidate => candidate.DeepClone()).ToArray())
        };
        var bytes = Encoding.UTF8.GetBytes(request.ToJsonString());
        var result = NativePolicyEvaluator.Evaluate(bytes);
        Assert.Equal(result, NativePolicyEvaluator.Evaluate(bytes));
        return JsonNode.Parse(result)!;
    }
    private static string[] TabIds(JsonNode plan, string field) =>
        plan[field]!.AsArray().Select(value => value!.GetValue<string>()).ToArray();
}
