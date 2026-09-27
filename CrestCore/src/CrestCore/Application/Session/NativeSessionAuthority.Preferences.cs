using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

public sealed partial class NativeSessionAuthority {
    #region Actions - App preferences

    /// The app-wide behavior preferences belong to the persistent workspace and
    /// stay on this device: sync neither uploads nor replaces them, and no
    /// edit of them reaches the journal.
    internal void RequirePreferenceOwner() {
        if (!workspaceKind.KeepsAppPreferences) throw new Rejected(new PersistentWorkspaceRequired(workspaceId));
    }

    /// `basis` with `preferences`, keeping its record when they are equal.
    internal SessionEdit Preferred(SessionState basis, AppPreferences preferences) =>
        new(preferences == basis.AppPreferences ? basis : basis with { AppPreferences = preferences }, Staging: null);

    /// How this launch treats the person's data and what its first window
    /// opens, with the startup choice this workspace keeps. Throws `Rejected`
    /// with `PersistentWorkspaceRequired` for any other workspace.
    internal LaunchDecision Plan(LaunchPlan query) {
        ArgumentNullException.ThrowIfNull(query);
        lock (Gate) {
            RequirePreferenceOwner();
            return LaunchPolicy.Plan(query.Environment, query.Platform, session.AppPreferences?.Startup, query.HasActiveLaunchGate);
        }
    }

    #endregion
}
