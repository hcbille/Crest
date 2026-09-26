namespace CrestCore.Contracts;

/// Why the engine warns about a download, or blocked it.
public enum EngineDownloadWarning {
    /// It came over a connection someone else could have changed.
    InsecureConnection,

    /// Its type of file can change the computer.
    DangerousFile,

    /// It is not commonly downloaded, so the engine could not confirm it is safe.
    UncommonContent,

    /// It may change the browser's or the computer's settings.
    PotentiallyUnwanted,

    /// The engine blocked it for its insecure connection.
    InsecureBlocked,

    /// The engine blocked it for its safety or organization policy verdict.
    PolicyBlocked
}
