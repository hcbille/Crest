namespace CrestCore.Contracts;

/// What a running transport reported of itself.
///
/// A report travels as its index in `All`, so `All` is append-only.
public sealed class CloudTransportReport {
    #region Variables

    public static readonly CloudTransportReport Stopped = new(name: "stopped");
    public static readonly CloudTransportReport Syncing = new(name: "syncing");
    public static readonly CloudTransportReport Idle = new(name: "idle");
    public static readonly CloudTransportReport PausedForAccountConfirmation = new(name: "pausedForAccountConfirmation");
    /// The transport failed; the report carries its words.
    public static readonly CloudTransportReport Failed = new(name: "failed");
    /// A batch of records arrived; the report counts the ones applied.
    public static readonly CloudTransportReport Fetched = new(name: "fetched");
    /// A batch of records uploaded; the report counts them.
    public static readonly CloudTransportReport Uploaded = new(name: "uploaded");
    /// The account changed under the running transport.
    public static readonly CloudTransportReport AccountChanged = new(name: "accountChanged");
    /// Records arrived that this build could not read; the report counts
    /// them, and whether a newer build wrote some.
    public static readonly CloudTransportReport SkippedRecords = new(name: "skippedRecords");
    /// Somebody removed Crest's data from iCloud.
    public static readonly CloudTransportReport CloudDataRemoved = new(name: "cloudDataRemoved");

    public static IReadOnlyList<CloudTransportReport> All { get; } =
        [Stopped, Syncing, Idle, PausedForAccountConfirmation, Failed, Fetched, Uploaded, AccountChanged, SkippedRecords, CloudDataRemoved];

    public string Name { get; }

    #endregion

    #region Constructors

    private CloudTransportReport(string name) => Name = name;

    #endregion
}
