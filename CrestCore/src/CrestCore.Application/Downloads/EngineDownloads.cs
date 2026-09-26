using System.Diagnostics;

using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The downloads engines run, in the core's download ledger. Each belongs to
/// the Space its page lives in, or else the one Space its profile belongs to; a
/// download no Space the person may see can hold is cancelled. Where a file
/// goes and whether to keep a file the engine warned about are prompts, which
/// settle when answered or when their download ends. The person's row actions
/// reach the engine as commands. Nothing here is saved or synced.
internal sealed class EngineDownloads(Downloads downloads, Device device, Pages pages, IIdSource ids) {
    #region Types

    /// One engine download the ledger records.
    private sealed class Tracked(Engine engine, Guid profileId, string engineId, Guid downloadId) {
        public Engine Engine { get; } = engine;
        public Guid ProfileId { get; } = profileId;
        public string EngineId { get; } = engineId;
        public Guid DownloadId { get; } = downloadId;
        public DownloadTransferEstimator? Estimator { get; set; }
        /// The engine still runs it; once it ends, later reports change nothing.
        public bool IsLive { get; set; } = true;
        /// The warning the approval waiting on the person is about.
        public string? ApprovalToken { get; set; }
    }

    /// What a download's prompt asks.
    private enum Question { Destination, Approval }

    #endregion

    #region Variables

    private const string CanceledMessage = "Canceled.";

    private readonly Dictionary<(Engine Engine, Guid ProfileId, string EngineId), Tracked> tracked = [];
    private readonly Dictionary<Guid, Tracked> byDownload = [];
    private readonly Dictionary<Guid, (Tracked Download, Question Question)> waiting = [];

    #endregion

    #region Actions - Reports

    /// Whether the report is about an engine download.
    public static bool Concerns(EngineEvent report) => report is EngineDownloadChanged or EngineDownloadDestinationRequested;

    public void Report(Engine engine, EngineEvent report, ChangeFeed changes, Action<Engine, EngineCommand> issue, DateTimeOffset now) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        switch (report) {
            case EngineDownloadChanged changed: Changed(engine, changed.Download, changes, issue, now); break;
            case EngineDownloadDestinationRequested requested: DestinationRequested(engine, requested, changes, issue, now); break;
            default: throw new ArgumentOutOfRangeException(nameof(report), report.GetType().Name, "Engine downloads do not handle this report.");
        }
    }

    private void Changed(Engine engine, EngineDownload reported, ChangeFeed changes, Action<Engine, EngineCommand> issue, DateTimeOffset now) {
        if (Track(engine, reported, changes, now) is not { } download) {
            issue(engine, new CancelEngineDownload(reported.ProfileId, reported.DownloadId));
            return;
        }
        if (!download.IsLive) return;
        if (reported.Path is { Length: > 0 } path) Record(new SetDownloadDestination(download.DownloadId, FileAddress(path), Path.GetFileName(path)), changes);
        var sample = new DownloadProgress(download.Estimator, reported.Received, reported.Total,
            reported.Total > 0 ? (double)reported.Received / reported.Total : 0, reported.Paused, Uptime);
        if (Sample(sample) is { } reading) {
            download.Estimator = reading.Estimator;
            Record(new RecordDownloadTransfer(download.DownloadId, reading.Telemetry, reading.Progress), changes);
        }
        switch (reported.State) {
            case EngineDownloadState.Preparing or EngineDownloadState.Downloading:
                // A warning the person or the engine resolved asks nothing more.
                SettleApproval(download, changes);
                break;
            case EngineDownloadState.Finished:
                Record(new FinishDownload(download.DownloadId, reported.Received), changes);
                End(download, changes);
                break;
            case EngineDownloadState.Canceled:
                Record(new CancelDownload(download.DownloadId, CanceledMessage), changes);
                End(download, changes);
                break;
            case EngineDownloadState.Failed:
                Record(new FailDownload(download.DownloadId, FailureOf(reported), reported.FailureDetail), changes);
                End(download, changes);
                break;
            case EngineDownloadState.AwaitingApproval when reported.Warning is null:
                // An approval with nothing to approve is never kept.
                issue(engine, new CancelEngineDownload(download.ProfileId, download.EngineId));
                break;
            case EngineDownloadState.AwaitingApproval when reported.Warning is { } warning:
                Record(new AwaitDownloadApproval(download.DownloadId), changes);
                if (download.ApprovalToken == reported.ApprovalToken) break;
                SettleApproval(download, changes);
                download.ApprovalToken = reported.ApprovalToken;
                var prompt = ids.Next();
                waiting[prompt] = (download, Question.Approval);
                changes.Publish(new DownloadApprovalAsked(prompt, download.DownloadId, DownloadFilename.Safe(reported.Filename), warning));
                break;
        }
    }

    private void DestinationRequested(Engine engine, EngineDownloadDestinationRequested requested, ChangeFeed changes,
        Action<Engine, EngineCommand> issue, DateTimeOffset now) {
        if (Track(engine, requested.Download, changes, now) is not { IsLive: true } download
            || SpaceOf(requested.Download) is not { } space) {
            issue(engine, new SettleDownloadDestination(requested.PromptId, Path: null));
            return;
        }
        waiting[requested.PromptId] = (download, Question.Destination);
        changes.Publish(new DownloadDestinationAsked(requested.PromptId, download.DownloadId, space,
            DownloadFilename.Safe(requested.SuggestedFilename), requested.ForcesPrompt));
    }

    /// The record of an engine download, begun on its first report in the
    /// Space it belongs to; null for one no Space can hold.
    private Tracked? Track(Engine engine, EngineDownload reported, ChangeFeed changes, DateTimeOffset now) {
        var key = (engine, reported.ProfileId, reported.DownloadId);
        if (tracked.TryGetValue(key, out var known)) return known;
        if (SpaceOf(reported) is null) return null;
        var download = new Tracked(engine, reported.ProfileId, reported.DownloadId, ids.Next());
        tracked[key] = download;
        byDownload[download.DownloadId] = download;
        // A download the engine restored from an earlier run is already known to the person.
        Record(new BeginDownload(download.DownloadId, reported.ProfileId, DownloadFilename.Safe(reported.Filename),
            reported.StartedAt == default ? now : reported.StartedAt, reported.Restored), changes);
        return download;
    }

    #endregion

    #region Actions - Intents

    /// Whether the answer is to one of the downloads' prompts.
    public static bool Concerns(PromptIntent intent) => intent is AnswerDownloadDestination or AnswerDownloadApproval;

    /// Runs one answer. A file going somewhere names the record's file; a file
    /// the person does not keep is cancelled at once.
    public void Handle(PromptIntent intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        if (!waiting.TryGetValue(intent.PromptId, out var prompt)) throw new Rejected(new UnknownPrompt(intent.PromptId));
        var download = prompt.Download;
        switch (prompt.Question, intent) {
            case (Question.Destination, AnswerDownloadDestination answer):
                Settle(answer.PromptId, changes);
                if (answer.Path is { Length: > 0 } path && download.IsLive)
                    Record(new SetDownloadDestination(download.DownloadId, FileAddress(path), Path.GetFileName(path)), changes);
                issue(download.Engine, new SettleDownloadDestination(answer.PromptId, answer.Path));
                break;
            case (Question.Approval, AnswerDownloadApproval answer):
                Settle(answer.PromptId, changes);
                if (answer.Approved) {
                    issue(download.Engine, new ApproveEngineDownload(download.ProfileId, download.EngineId, download.ApprovalToken ?? ""));
                } else {
                    issue(download.Engine, new CancelEngineDownload(download.ProfileId, download.EngineId));
                    Record(new CancelDownload(download.DownloadId, CanceledMessage), changes);
                    End(download, changes);
                }
                break;
            default:
                throw new Rejected(new PromptAnswerMismatch(intent.PromptId));
        }
    }

    /// Before the ledger runs a download intent: an engine download the person
    /// cancels is cancelled on its engine, one they clear leaves the engine's
    /// list, and deleting a profile's data does both for each of its downloads.
    public void Before(DownloadIntent intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        switch (intent) {
            case CancelDownload cancellation when byDownload.GetValueOrDefault(cancellation.DownloadId) is { IsLive: true } download:
                issue(download.Engine, new CancelEngineDownload(download.ProfileId, download.EngineId));
                End(download, changes);
                break;
            case RemoveDownload removal when byDownload.GetValueOrDefault(removal.DownloadId) is { IsLive: false } download:
                issue(download.Engine, new RemoveEngineDownload(download.ProfileId, download.EngineId));
                break;
            case RemoveProfileDownloads removal:
                foreach (var download in byDownload.Values.Where(download => download.ProfileId == removal.ProfileId)) {
                    if (download.IsLive) issue(download.Engine, new CancelEngineDownload(download.ProfileId, download.EngineId));
                    issue(download.Engine, new RemoveEngineDownload(download.ProfileId, download.EngineId));
                    End(download, changes);
                }
                break;
        }
    }

    #endregion

    #region Actions - Rules

    /// The download ended: what it asked no longer waits, and later reports
    /// about it change nothing. Its identity stays, so a late report cannot
    /// bring back a record the person cleared.
    private void End(Tracked download, ChangeFeed changes) {
        download.IsLive = false;
        foreach (var (id, _) in waiting.Where(entry => entry.Value.Download == download).ToArray()) Settle(id, changes);
    }

    private void SettleApproval(Tracked download, ChangeFeed changes) {
        download.ApprovalToken = null;
        foreach (var (id, _) in waiting.Where(entry => entry.Value.Download == download && entry.Value.Question == Question.Approval)
                     .ToArray())
            Settle(id, changes);
    }

    private void Settle(Guid promptId, ChangeFeed changes) {
        if (waiting.Remove(promptId)) changes.Publish(new PromptSettled(promptId));
    }

    /// The Space a download belongs to: its page's, while the page lives in a
    /// Space of the download's profile, or else the one Space of that profile
    /// the person may see.
    private Guid? SpaceOf(EngineDownload reported) {
        if (reported.SourcePageId is { } pageId && pages.Hosted(pageId) is { } page && page.ProfileId == reported.ProfileId
            && device.Attached(page.WorkspaceId) is { } workspace
            && workspace.Current.Spaces.FirstOrDefault(space => space.Id == page.SpaceId) is { } pageSpace
            && !workspace.IsDeleting(pageSpace.Id) && !workspace.IsLocked(pageSpace))
            return pageSpace.Id;
        return device.OnlySpaceOf(reported.ProfileId);
    }

    /// Runs a ledger intent the engine's report implies. One the ledger refuses,
    /// such as a reading for a record that already ended, changes nothing.
    private void Record(DownloadIntent intent, ChangeFeed changes) {
        try {
            downloads.Handle(intent, changes);
        } catch (Rejected) {
            // The ledger keeps what it had.
        }
    }

    private DownloadProgressReading? Sample(DownloadProgress sample) {
        try {
            return downloads.Answer(sample);
        } catch (Rejected) {
            return null;
        }
    }

    /// The file's address as the ledger names destinations.
    private static string FileAddress(string path) => new Uri(path).AbsoluteUri;

    /// A monotonic clock in seconds, which transfer rates are measured by.
    private static double Uptime => Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;

    /// Why a download the engine stopped failed: the warning it was blocked
    /// for, else what interrupted it.
    private static DownloadFailure FailureOf(EngineDownload reported) => reported.Warning switch {
        EngineDownloadWarning.InsecureBlocked or EngineDownloadWarning.InsecureConnection => DownloadFailure.BlockedInsecure,
        EngineDownloadWarning.PolicyBlocked => DownloadFailure.BlockedByPolicy,
        EngineDownloadWarning.DangerousFile or EngineDownloadWarning.UncommonContent or EngineDownloadWarning.PotentiallyUnwanted =>
            DownloadFailure.BlockedUnsafe,
        _ => reported.Interruption switch {
            EngineDownloadInterruption.Network => DownloadFailure.Network,
            EngineDownloadInterruption.Server => DownloadFailure.Server,
            EngineDownloadInterruption.NoSpace => DownloadFailure.NoSpace,
            EngineDownloadInterruption.FileAccess => DownloadFailure.FileAccess,
            _ => DownloadFailure.Interrupted
        }
    };

    #endregion
}
