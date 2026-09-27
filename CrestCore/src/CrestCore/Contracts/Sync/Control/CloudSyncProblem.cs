namespace CrestCore.Contracts;

/// A reason the core found for sync to need attention, as opposed to a
/// failure the platform reported in its own words.
///
/// A problem travels as its index in `All`, so `All` is append-only.
public sealed class CloudSyncProblem {
    #region Variables

    /// This build has no CloudKit container or no transport to reach it.
    public static readonly CloudSyncProblem NotConfigured = new(name: "notConfigured", reportsError: false);
    /// This build lacks the entitlement for Crest's container.
    public static readonly CloudSyncProblem EntitlementMissing = new(name: "entitlementMissing", reportsError: true);
    /// The core could not stage or save this device's latest edits, so a
    /// finished sync is not a success.
    public static readonly CloudSyncProblem LocalChangesUnsaved = new(name: "localChangesUnsaved", reportsError: true);

    public static IReadOnlyList<CloudSyncProblem> All { get; } = [NotConfigured, EntitlementMissing, LocalChangesUnsaved];

    public string Name { get; }

    /// Whether the problem shows as an error, which activity from a working
    /// transport clears.
    public bool ReportsError { get; }

    #endregion

    #region Constructors

    private CloudSyncProblem(string name, bool reportsError) {
        Name = name;
        ReportsError = reportsError;
    }

    #endregion
}
