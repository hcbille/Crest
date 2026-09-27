using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// What `Input`, as a person typed it, loads: an address as it is, or a
/// search with the search engine of `SpaceId` in `WorkspaceId`. Without a
/// workspace, as a setup draft whose Spaces do not exist yet, it searches with
/// Google, opens no internal page and reads no state, so a host may ask it
/// without an app.
public sealed record ResolveAddress(Guid? WorkspaceId, Guid? SpaceId, string Input) : Query<ResolvedAddress> {
    #region Actions - Answering

    /// An address that names a workspace resolves with the search engine of
    /// the Space it names, or Google when it names none, and opens an internal
    /// page when the default engine shows them.
    internal override ResolvedAddress Answer(CrestApp app) {
        if (WorkspaceId is not { } workspaceId) return Unplaced();
        var provider = SpaceId is { } spaceId ? app.Device.Workspace(workspaceId).Searches(spaceId).Selected : SearchProvider.Google;
        return NativeSessionAuthority.Resolved(Input, provider, app.Pages.OpensInternalPages);
    }

    /// What the address resolves to outside any workspace: Google searches
    /// what is not an address, and no internal page opens.
    internal ResolvedAddress Unplaced() => NativeSessionAuthority.Resolved(Input, SearchProvider.Google, allowsInternalPages: false);

    #endregion
}
