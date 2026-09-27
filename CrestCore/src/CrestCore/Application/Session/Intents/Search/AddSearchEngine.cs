using CrestCore.Application;

namespace CrestCore.Contracts;

/// Adds a custom search engine to a Space, trimmed and validated, after the
/// others, and searches with it when `Selects`.
public sealed record AddSearchEngine(Guid WorkspaceId, Guid SpaceId, CustomSearchEngine Engine, bool Selects)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        var engine = workspace.Admitted(Engine);
        return workspace.Searching(turn.Basis, workspace.Editable(turn.Basis, SpaceId), search => {
            var added = search.Add(engine);
            return Selects ? added.Select(engine) : added;
        });
    }

    #endregion
}
