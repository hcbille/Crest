using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// How this launch treats the person's data and what its first window opens,
/// with the startup choice the persistent workspace keeps. First-run setup
/// that owns the first window is an active launch gate.
public sealed record LaunchPlan(Guid WorkspaceId, DevicePlatform Platform, LaunchEnvironment Environment, bool HasActiveLaunchGate)
    : Query<LaunchDecision> {
    #region Actions - Answering

    internal override LaunchDecision Answer(CrestApp app) => Answer(app.Device.Workspace(WorkspaceId));

    /// How this launch treats the person's data and what its first window
    /// opens, with the startup choice this workspace keeps. Throws `Rejected`
    /// with `PersistentWorkspaceRequired` for any other workspace.
    private LaunchDecision Answer(NativeSessionAuthority workspace) {
        lock (NativeSessionAuthority.Gate) {
            workspace.RequirePreferenceOwner();
            return LaunchPolicy.Plan(Environment, Platform, workspace.AcceptedSession.AppPreferences?.Startup, HasActiveLaunchGate);
        }
    }

    #endregion
}
