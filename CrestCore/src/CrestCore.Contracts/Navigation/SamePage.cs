namespace CrestCore.Contracts;

/// Whether two addresses name one page, as `WebAddress.IsSamePage` decides.
/// It reads no state, so a host may ask it without an app.
public sealed record SamePage(string First, string Second) : Query<PageMatch>;
