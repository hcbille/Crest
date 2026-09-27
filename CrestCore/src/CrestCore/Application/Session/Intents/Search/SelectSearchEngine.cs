using CrestCore.Application;

namespace CrestCore.Contracts;

/// Makes a Space search with a built-in engine or with one of its custom
/// engines; exactly one of `BuiltIn` and `CustomEngineId` names it.
public sealed record SelectSearchEngine(Guid WorkspaceId, Guid SpaceId, BuiltInSearchEngine? BuiltIn, Guid? CustomEngineId)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        var space = workspace.Editable(turn.Basis, SpaceId);
        return workspace.Searching(turn.Basis, space, search => (BuiltIn, CustomEngineId) switch {
            ( { } builtIn, null) => search.Select(builtIn.Provider()),
            (null, { } custom) => search.Select(custom),
            _ => throw new Rejected(new UnknownSearchEngine(CustomEngineId))
        });
    }

    #endregion
}
