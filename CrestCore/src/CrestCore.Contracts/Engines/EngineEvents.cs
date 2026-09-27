namespace CrestCore.Contracts;

/// Something an engine binding saw happen to one of its pages. A report is
/// never refused: one about a page the core no longer knows changes nothing.
public abstract record EngineEvent;

#region Pages

/// The engine's page is gone: the core asked the engine to close it, or the
/// page closed itself, as `window.close()` does. A page closed keeping its
/// state hands back what brings it back, when its engine can.
public sealed record PageClosed(Guid PageId, PageRestoreState? RestoreState) : EngineEvent;

/// A page's renderer stopped: it crashed, or the system ended it. The document
/// it showed is gone, and the core decides whether the engine brings it back.
/// `Domain` and `Code` are the engine's own reason, which a failure page shows
/// as technical details and nothing branches on.
public sealed record PageCrashed(Guid PageId, string Domain, long Code) : EngineEvent;

/// The engine created the page, which is now live.
public sealed record PageCreated(Guid PageId) : EngineEvent;

/// The engine could not create the page.
public sealed record PageCreationFailed(Guid PageId) : EngineEvent;

/// The engine found an icon for the document a page shows at `Url`, or the
/// color the page's theme puts behind it changed. The binding keeps the
/// image; once the document is recorded, the core has the page's tab wear it
/// when the tab's icon follows its page.
public sealed record PageIconChanged(Guid PageId, string Url, TabIconAccent? Accent) : EngineEvent;

/// The engine opened a page of its own in the profile `ProfileId` names: a
/// script's `window.open`, a link to a new window or tab, or an extension's
/// tab. `SourcePageId` names the page that opened it, when one did. Otherwise
/// `WindowId` names the Crest window whose engine window holds it, and
/// `SpaceId` the Space a window the engine created for itself was reserved
/// for. `Url` is where it is heading, and `Foreground` whether the engine
/// brought it to the front. The core adopts it with `AdoptOfferedPage` or
/// refuses it with `RejectOfferedPage`.
public sealed record PageOffered(Guid OfferId, Guid ProfileId, Guid? SourcePageId, Guid? WindowId, Guid? SpaceId, string Url,
    bool Foreground) : EngineEvent;

/// What a page's engine shows changed. A binding reports a page's latest
/// snapshot at most once per turn, and only when it differs from the last one
/// it reported.
public sealed record PageStateChanged(Guid PageId, PageSnapshot Snapshot) : EngineEvent;

/// The page's document, or a frame of its own site, asked for `KeySystem`,
/// which the engine does not have. The core moves the page to an engine that
/// plays protected media through the platform, when one is registered.
public sealed record ProtectedMediaUnavailable(Guid PageId, KeySystem KeySystem) : EngineEvent;

#endregion

#region Navigation

/// A page's navigation took effect at `Url`. A new document begins a record
/// of its own; a move within the document begins one only when it reaches
/// another page, since a fragment is part of the page it names.
public sealed record NavigationCommitted(Guid PageId, string Url, bool SameDocument) : EngineEvent;

/// A page's navigation failed as `Failure` describes, so the document it was
/// loading records nothing, and the page shows the failure until another
/// navigation begins.
public sealed record NavigationFailed(Guid PageId, PageFailure Failure) : EngineEvent;

/// A page's navigation finished at `Url`, titled `Title`, which may be empty.
/// The core records the first finish of each document: the tab that owns the
/// page shows the address and title, and the Space's history holds a visit. A
/// move within the document finishes once its title settles.
public sealed record NavigationFinished(Guid PageId, string Url, string Title) : EngineEvent;

/// A page began navigating to `Url`: a load that will replace its document,
/// or, when `SameDocument`, a move within the document it shows, such as
/// `history.pushState` or a fragment. Nothing is recorded until the
/// navigation finishes.
public sealed record NavigationStarted(Guid PageId, string Url, bool SameDocument) : EngineEvent;

/// The link staged for the page's first load no longer applies, so the page
/// did not load it. A stale link is never retried as a bare address, which
/// would lose where it was followed.
public sealed record StagedLinkUnavailable(Guid PageId) : EngineEvent;

#endregion

#region Prompts

/// A server a page loads from asked for a user name and password; the load
/// waits for the core's `SettleAuthentication`.
public sealed record AuthenticationChallenged(Guid PromptId, Guid PageId, AuthenticationQuestion Question) : EngineEvent;

/// Whether a page the core asked may go.
public sealed record BeforeUnloadAnswered(Guid PageId, bool Proceeds) : EngineEvent;

/// An extension install the window `WindowId` started needs the person's
/// approval, which waits for the core's `SettleExtensionInstall`.
public sealed record ExtensionInstallRequested(Guid PromptId, Guid WindowId, ExtensionInstallQuestion Question) : EngineEvent;

/// A document in a page asked for a permission Crest records, which waits for
/// the core's `SettlePermission`. The core answers from the Space's choices
/// when they hold one, and asks the person only when they do not.
public sealed record PermissionRequested(Guid PromptId, Guid PageId, PermissionQuestion Question) : EngineEvent;

/// The engine no longer waits for a prompt's answer: the page moved on, or
/// what asked went away.
public sealed record PromptWithdrawn(Guid PromptId) : EngineEvent;

/// A document in a page opened a script dialog, which waits for the core's
/// `SettleScriptDialog`.
public sealed record ScriptDialogOpened(Guid PromptId, Guid PageId, ScriptDialogQuestion Question) : EngineEvent;

#endregion

#region Downloads

/// An engine download started, progressed, finished or failed. The core
/// records it in the download ledger, in the Space its page or profile belongs
/// to, and asks the person to keep a file the engine warned about.
public sealed record EngineDownloadChanged(EngineDownload Download) : EngineEvent;

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
    bool ForcesPrompt, DownloadRiskFacts Facts, bool UserInitiated, string? SourceHost) : EngineEvent;

#endregion

#region Website Data

/// An erasure the core asked for ended: `Erased` says nothing it covered is
/// left.
public sealed record DataErased(Guid ErasureId, bool Erased) : EngineEvent;

#endregion
