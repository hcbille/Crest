using CrestCore.Application;

namespace CrestCore.Contracts;

/// Sets whether a Space offers to save and fill passwords, and where it keeps them.
public sealed record SetCredentialPreferences(Guid WorkspaceId, Guid SpaceId, CredentialPreferences Preferences)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        return workspace.SettingSpace(turn.Basis, workspace.Editable(turn.Basis, SpaceId),
            settings => settings with { CredentialPreferences = Preferences },
            SyncStaging.Protection);
    }

    #endregion
}
