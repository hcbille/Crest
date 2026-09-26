namespace CrestCore.Contracts;

/// Where iCloud sync stands.
///
/// A phase travels as its index in `All`, so `All` is append-only.
public sealed class CloudSyncPhase {
    #region Variables

    public static readonly CloudSyncPhase Disabled = new(name: "disabled", isRetryable: false);
    public static readonly CloudSyncPhase Checking = new(name: "checking", isRetryable: false);
    public static readonly CloudSyncPhase Ready = new(name: "ready", isRetryable: false);
    public static readonly CloudSyncPhase Syncing = new(name: "syncing", isRetryable: false);
    public static readonly CloudSyncPhase NeedsReconciliation = new(name: "needsReconciliation", isRetryable: false);
    public static readonly CloudSyncPhase WaitingForAccount = new(name: "waitingForAccount", isRetryable: true);
    public static readonly CloudSyncPhase Failed = new(name: "failed", isRetryable: true);

    public static IReadOnlyList<CloudSyncPhase> All { get; } =
        [Disabled, Checking, Ready, Syncing, NeedsReconciliation, WaitingForAccount, Failed];

    public string Name { get; }

    /// Whether trying the same thing again could reach a different answer. A
    /// missing account and a failed launch both heal on their own once iCloud
    /// is reachable; everything else is working, in progress, or waiting on a
    /// decision only somebody using Crest can make.
    public bool IsRetryable { get; }

    #endregion

    #region Constructors

    private CloudSyncPhase(string name, bool isRetryable) {
        Name = name;
        IsRetryable = isRetryable;
    }

    #endregion
}
