using CrestCore.Application;

namespace CrestCore.Contracts;

/// Sets whether a Space opens freely or asks the device owner first. Asking
/// for authentication is always allowed; letting a locked Space open freely
/// takes the grant that unlocking it gives.
public sealed record SetSpaceAccess(Guid WorkspaceId, Guid SpaceId, SpaceAccessPolicy Policy) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    /// Asking for authentication is always allowed, even for a locked Space;
    /// letting a Space open freely is the decision authentication guards.
    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        var space = workspace.Editable(turn.Basis, SpaceId, maintains: Policy != SpaceAccessPolicy.Open);
        return workspace.SettingSpace(turn.Basis, space, settings => settings with { AccessPolicy = Policy }, SyncStaging.Protection);
    }

    #endregion
}
