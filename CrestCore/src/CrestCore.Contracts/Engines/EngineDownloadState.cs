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
    Failed
}
