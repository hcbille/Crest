namespace CrestCore.Contracts;

/// The Spaces one password goes to, none when it goes nowhere.
public sealed record ImportPasswordRoute(IReadOnlyList<Guid> SpaceIds);
