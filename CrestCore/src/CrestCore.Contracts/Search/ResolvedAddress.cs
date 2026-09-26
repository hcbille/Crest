namespace CrestCore.Contracts;

/// The address typed input loads, or null when it names nothing a page can
/// load. `SearchQuery` is the text searched for when the address is a search.
public sealed record ResolvedAddress(string? Url, string? SearchQuery);
