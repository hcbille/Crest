namespace CrestCore.Contracts;

#region Intents

/// An intent the downloads ledger handles.
public abstract record DownloadIntent : Intent;

/// Opening a profile's downloads acknowledges its records without clearing them.
public sealed record AcknowledgeDownloads(Guid ProfileId) : DownloadIntent;

/// Whether the person keeps a file the engine warned about. A file not kept
/// is cancelled.
public sealed record AnswerDownloadApproval(Guid PromptId, bool Approved) : PromptIntent(PromptId);

/// Where the file of a download goes, as the platform resolved it or the person
/// chose it, or none to cancel the download.
public sealed record AnswerDownloadDestination(Guid PromptId, string? Path) : PromptIntent(PromptId);

/// Records a live download's risk. Any reason makes it wait for approval under
/// its sanitized name.
public sealed record AssessDownloadRisk(Guid DownloadId, DownloadRiskAssessment Assessment) : DownloadIntent;

/// A live download waits for the person's approval.
public sealed record AwaitDownloadApproval(Guid DownloadId) : DownloadIntent;

/// Records a new download as preparing, ahead of every existing record. The
/// caller supplies the identity and creation time so a retried call is
/// deterministic. A download an engine restored from an earlier run starts
/// acknowledged.
public sealed record BeginDownload(Guid DownloadId, Guid ProfileId, string Filename, DateTimeOffset CreatedAt,
    bool IsAcknowledged) : DownloadIntent;

/// A live automatic download was blocked and waits for the person to retry it.
public sealed record BlockAutomaticDownload(Guid DownloadId) : DownloadIntent;

/// A live download was canceled.
public sealed record CancelDownload(Guid DownloadId, string Message) : DownloadIntent;

/// Removes finished, canceled, failed and blocked records whose age strictly
/// exceeds their profile's retention. When several Spaces share a profile the
/// shortest retention wins; a profile with no limit keeps its records.
public sealed record ExpireDownloads(DateTimeOffset Now, IReadOnlyList<DownloadRetention> Retentions)
    : DownloadIntent;

/// One Space's download retention for the profile it uses. A null lifetime
/// keeps records forever.
public sealed record DownloadRetention(Guid ProfileId, TimeSpan? Lifetime);

/// A live or blocked download failed, for `Reason` when it is known, with the
/// engine's or platform's own `Message` when it has one; one of the two is
/// given. A blocked automatic download fails when its retry can no longer be
/// replayed.
public sealed record FailDownload(Guid DownloadId, DownloadFailure? Reason, string? Message) : DownloadIntent;

/// A live download finished with the bytes actually written, when known.
public sealed record FinishDownload(Guid DownloadId, long? FinalByteCount) : DownloadIntent;

/// One transfer reading for a live download. Progress never moves backwards.
public sealed record RecordDownloadTransfer(Guid DownloadId, DownloadTelemetry Telemetry, double Progress)
    : DownloadIntent;

/// Clears one record. Files already written stay on disk; the caller refuses to
/// clear a record whose transfer it still owns.
public sealed record RemoveDownload(Guid DownloadId) : DownloadIntent;

/// Deleting a profile's data removes every record it owns, live or not. The
/// caller cancels the matching transfers.
public sealed record RemoveProfileDownloads(Guid ProfileId) : DownloadIntent;

/// Retrying a blocked automatic download starts the same record again from
/// nothing and counts as news for the downloads badge.
public sealed record RestartDownload(Guid DownloadId) : DownloadIntent;

/// Names the file a live download writes. The record's filename follows the
/// destination's.
public sealed record SetDownloadDestination(Guid DownloadId, string Destination, string Filename) : DownloadIntent;

#endregion

#region Queries

/// Whether a download a page starts goes ahead, is refused or asks first:
/// whether a person's gesture started it or approved a retry, the site's saved
/// decision, and whether the page has already had its one automatic download
/// while that decision is Ask.
public sealed record AutomaticDownloadCheck(bool UserInitiated, bool UserApprovedRetry, SitePermissionDecision SavedDecision,
    bool HasAllowedAutomaticDownload) : Query<AutomaticDownloadVerdict>;

/// The action for one download and the throttle state its page and origin
/// carry into the next automatic download.
public sealed record AutomaticDownloadVerdict(AutomaticDownloadAction Action, bool HasAllowedAutomaticDownload);

/// One engine progress sample for a transfer. `Estimator` is the state the
/// previous reading returned, or null for the first sample. `Uptime` is a
/// monotonic clock in seconds; `FractionCompleted` is used only while no total
/// is known.
public sealed record DownloadProgress(DownloadTransferEstimator? Estimator, long CompletedUnitCount, long TotalUnitCount,
    double FractionCompleted, bool IsPaused, double Uptime) : Query<DownloadProgressReading>;

/// Why a download looks dangerous and whether, given how it started, the
/// person must confirm it before it continues.
public sealed record DownloadRisk(DownloadRiskFacts Facts, bool IsUserInitiated) : Query<DownloadRiskVerdict>;

/// A download's risk assessment and whether the person must confirm it.
public sealed record DownloadRiskVerdict(DownloadRiskAssessment Assessment, bool RequiresConfirmation);

#endregion

#region Changes

/// Whether to keep the file of the download `DownloadId` waits on the person:
/// the core's `Reasons` it looks dangerous, and the engine's `Warning` when the
/// engine warned about it. `SpaceId` is the Space it belongs to and
/// `SourceHost` the host it came from, when known.
public sealed record DownloadApprovalAsked(Guid PromptId, Guid DownloadId, Guid? SpaceId, string Filename,
    IReadOnlyList<DownloadRiskReason> Reasons, EngineDownloadWarning? Warning, string? SourceHost) : Change;

/// Where the file of the download `DownloadId` goes waits on the platform: the
/// download folder of the Space `SpaceId`, or the person's choice when
/// `ForcesPrompt` asks for one or that Space asks every time.
public sealed record DownloadDestinationAsked(Guid PromptId, Guid DownloadId, Guid SpaceId, string SuggestedFilename,
    bool ForcesPrompt) : Change;

/// A download record changed or began. `Position` is its place in the
/// newest-first list after the change.
public sealed record DownloadUpdated(DownloadState Download, int Position) : Change;

/// One download record owned by a browsing profile. `Failure` says why a
/// failed record stopped, when that is known; `Message` explains a canceled or
/// failed record in words its engine or platform gave. Both are null in every
/// other phase.
public sealed record DownloadState(Guid Id, Guid ProfileId, DateTimeOffset CreatedAt, string Filename, string? Destination,
    double Progress, DownloadTelemetry Telemetry, DownloadPhase Phase, DownloadFailure? Failure, string? Message,
    DownloadRiskAssessment? Risk, bool IsAcknowledged);

/// Download records that were cleared, expired or removed with their profile.
public sealed record DownloadsRemoved(IReadOnlyList<Guid> DownloadIds) : Change;

#endregion

#region Rejections

/// The ledger already holds `Limit` records.
public sealed record DownloadLimitReached(int Limit) : Rejection;

/// A download with this identity is already recorded.
public sealed record DuplicateDownload() : Rejection;

/// A download or its profile has an empty identity.
public sealed record InvalidDownloadIdentity() : Rejection;

/// Transfer telemetry, progress or a final byte count is negative or not a number.
public sealed record InvalidDownloadProgress() : Rejection;

/// A progress sample's estimator state or clock reading is not valid.
public sealed record InvalidDownloadSample() : Rejection;

/// A download's text field is empty or longer than its limit.
public sealed record InvalidDownloadText(DownloadTextField Field) : Rejection;

/// A download retention lifetime is negative.
public sealed record InvalidRetentionLifetime() : Rejection;

#endregion

#region Models

/// One published transfer reading: the estimator state to send with the next
/// sample, the row telemetry and a progress in [0, 1].
public sealed record DownloadProgressReading(DownloadTransferEstimator Estimator, DownloadTelemetry Telemetry, double Progress);

#endregion
