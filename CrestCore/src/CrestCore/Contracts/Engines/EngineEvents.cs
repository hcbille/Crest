namespace CrestCore.Contracts;

#region Prompts

/// A server a page loads from asked for a user name and password; the load
/// waits for the core's `SettleAuthentication`.
public sealed record AuthenticationChallenged(Guid PromptId, Guid PageId, AuthenticationQuestion Question) : PromptEvent(PromptId);

/// An extension install the window `WindowId` started needs the person's
/// approval, which waits for the core's `SettleExtensionInstall`.
public sealed record ExtensionInstallRequested(Guid PromptId, Guid WindowId, ExtensionInstallQuestion Question) : PromptEvent(PromptId);

/// A document in a page asked for a permission Crest records, which waits for
/// the core's `SettlePermission`. The core answers from the Space's choices
/// when they hold one, and asks the person only when they do not.
public sealed record PermissionRequested(Guid PromptId, Guid PageId, PermissionQuestion Question) : PromptEvent(PromptId);

/// The engine no longer waits for a prompt's answer: the page moved on, or
/// what asked went away.
public sealed record PromptWithdrawn(Guid PromptId) : PromptEvent(PromptId);

/// A document in a page opened a script dialog, which waits for the core's
/// `SettleScriptDialog`.
public sealed record ScriptDialogOpened(Guid PromptId, Guid PageId, ScriptDialogQuestion Question) : PromptEvent(PromptId);

#endregion

#region Downloads

/// An engine download started, progressed, finished or failed. The core
/// records it in the download ledger, in the Space its page or profile belongs
/// to, and asks the person to keep a file the engine warned about.
public sealed record EngineDownloadChanged(EngineDownload Download) : EngineDownloadEvent(Download);

/// A download the engine runs for one of Crest's profiles: the page it came
/// from, its file and progress, and a warning the person may override while it
/// is still the one `ApprovalToken` names. A failed download says what
/// interrupted it, and `FailureDetail` is the engine's own description of
/// that. `DownloadId` is the engine's own name for it within its profile.
public sealed record EngineDownload(string DownloadId, Guid ProfileId, Guid? SourcePageId, string Filename, string? Path,
    long Received, long Total, DateTimeOffset StartedAt, bool Restored, bool Paused, EngineDownloadState State,
    EngineDownloadWarning? Warning, EngineDownloadInterruption? Interruption, string? FailureDetail, string ApprovalToken);

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

/// Where a download's file goes, asked before it begins: `SuggestedFilename`
/// is the engine's name for it, and `ForcesPrompt` asks the person to choose.
/// The download waits for the core's `SettleDownloadDestination`, which first
/// judges its risk from the platform's `Facts` and whether the person started
/// it: a download the person must confirm is asked about before its place.
/// `SourceHost` is the host the file came from, which that question shows; the
/// engine never sends the address itself.
public sealed record EngineDownloadDestinationRequested(Guid PromptId, EngineDownload Download, string SuggestedFilename,
    bool ForcesPrompt, DownloadRiskFacts Facts, bool UserInitiated, string? SourceHost) : EngineDownloadEvent(Download);

#endregion
