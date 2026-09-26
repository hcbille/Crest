namespace CrestCore.Contracts;

/// Where an engine download stands.
public enum EngineDownloadState {
    /// Its file is not chosen yet.
    Preparing,

    Downloading,

    /// It waits for the person to keep a file its warning describes.
    AwaitingApproval,

    Finished,
    Canceled,

    /// It stopped: `Failure` or its warning says why.
    Failed,

    /// A download the site sent without the person's gesture, which the
    /// Space's choices refused. It waits for the person to retry it, which
    /// the engine hears as an approval of its `ApprovalToken` and replays
    /// under the same `DownloadId`.
    Blocked
}
