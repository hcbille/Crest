using System.Text.Json.Nodes;

using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Wire spellings for the page-residency and tab-selection
/// policy operations. They match the native lifecycle models'
/// case names.
internal static class TabPolicyCodes {
    #region Actions - Encoding

    public static JsonObject ReleaseLimitAnswer(int limit) => new() { ["limit"] = limit };

    public static JsonObject ReleasePlanAnswer(IReadOnlyList<string> offScreen, IReadOnlyList<string> presentedFallback) => new() {
        ["tabIDs"] = Identifiers(offScreen),
        ["fallbackTabIDs"] = Identifiers(presentedFallback)
    };

    private static JsonArray Identifiers(IReadOnlyList<string> values) =>
        new(values.Select(value => (JsonNode?)JsonValue.Create(value)).ToArray());

    #endregion
}
