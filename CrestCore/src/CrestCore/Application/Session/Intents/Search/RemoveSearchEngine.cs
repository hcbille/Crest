using CrestCore.Application;

namespace CrestCore.Contracts;

/// Removes one of a Space's custom search engines. A Space that searched with
/// it searches with Google.
public sealed record RemoveSearchEngine(Guid WorkspaceId, Guid SpaceId, Guid EngineId) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        return workspace.Searching(turn.Basis, workspace.Editable(turn.Basis, SpaceId), search => search.Remove(EngineId));
    }

    #endregion
}
