namespace CrestCore.Contracts;

/// The Spaces an import would bring, in order, each with new identities, the
/// way `ImportSpaces` takes them.
public sealed record ImportedSpaces(IReadOnlyList<SpaceState> Spaces);
