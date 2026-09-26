namespace CrestCore.Contracts;

/// What `Input`, as a person typed it, loads: an address as it is, or a
/// search with the search engine of `SpaceId` in `WorkspaceId`. Without a
/// workspace, as a setup draft whose Spaces do not exist yet, it searches with
/// Google, opens no internal page and reads no state, so a host may ask it
/// without an app.
public sealed record ResolveAddress(Guid? WorkspaceId, Guid? SpaceId, string Input) : Query<ResolvedAddress>;
