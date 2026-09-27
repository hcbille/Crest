namespace CrestCore.Contracts;

/// The address history keeps for each of `Addresses`, as `WebAddress`
/// normalizes it: an http or https address without its fragment, or none. It
/// reads no state, so a host may ask it without an app.
public sealed record HistoryAddresses(IReadOnlyList<string> Addresses) : Query<HistoryAddressList>;

/// For each asked address, in order, the address history keeps for it, or
/// null for one history does not keep.
public sealed record HistoryAddressList(IReadOnlyList<string?> Normalized);

/// Whether two addresses name one page, as `WebAddress.IsSamePage` decides.
/// It reads no state, so a host may ask it without an app.
public sealed record SamePage(string First, string Second) : Query<PageMatch>;

/// Whether two addresses name one page.
public sealed record PageMatch(bool IsSamePage);
