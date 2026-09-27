using CrestCore.Application;

namespace CrestCore.Contracts;

/// Replaces one of a Space's custom search engines, which keeps its place and
/// may keep its own name.
public sealed record UpdateSearchEngine(Guid WorkspaceId, Guid SpaceId, CustomSearchEngine Engine) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        var engine = workspace.Admitted(Engine);
        return workspace.Searching(turn.Basis, workspace.Editable(turn.Basis, SpaceId), search => search.Update(engine));
    }

    #endregion
}
