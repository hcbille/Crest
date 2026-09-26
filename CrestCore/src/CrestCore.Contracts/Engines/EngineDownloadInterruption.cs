namespace CrestCore.Contracts;

/// What stopped an engine download before its file was saved.
public enum EngineDownloadInterruption {
    /// The connection failed, timed out or went away.
    Network,

    /// The server refused the file or could not provide it.
    Server,

    /// The disk has no room for the file.
    NoSpace,

    /// The file could not be written where it was going.
    FileAccess,

    /// Anything else, such as the engine stopping.
    Other
}
