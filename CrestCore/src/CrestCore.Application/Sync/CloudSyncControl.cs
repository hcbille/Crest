using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Decides what iCloud sync does on this device: when it starts, what a
/// start checks and in which order, when the first launch takes the cloud's
/// content, when an account change waits for the person and what their
/// choice applies, when a sync or a pull counts as a success, and when a
/// failed launch is retried. The platform takes the steps it answers, which
/// reach CloudKit and the transport, and reports what each came to; a result
/// for a start that is no longer current changes only what it must.
internal sealed class CloudSyncControl {
    #region Static Variables

    /// A launch that could not reach iCloud is retried this many times; a
    /// signed-out account heals through `ObserveCloudAccountAvailability`
    /// instead of through polling.
    private const int MaximumRetryAttempts = 3;

    #endregion

    #region Variables

    private readonly Lock gate = new();
    private readonly CloudTransportStore transport;
    private readonly IClock clock;
    /// Whether the session the core keeps in its file is still the disposable
    /// seed a first launch made, which the cloud's content replaces.
    private readonly Func<bool> seedIsDisposable;

    private bool enabled = true;
    private bool canReachCloud;
    private CloudAccountState account = CloudAccountState.Checking;
    private CloudSyncPhase phase = CloudSyncPhase.Checking;
    private CloudSyncProblem? problem;
    private string? failureMessage;
    private DateTimeOffset? lastAttemptAt, lastSuccessAt;
    private int lastFetched, lastUploaded, skipped;
    private int? observedCloud;
    private CloudContentComparison? conflict;
    private bool requiresAppUpdate, cloudDataRemoved;

    /// The platform holds a transport, started or starting.
    private bool transportLive;
    /// A start, sync, pull or choice is under way.
    private bool running;
    private bool accountRestartRequested;
    /// The current start; results for an earlier one are stale.
    private long attempt;
    private bool retryScheduled;
    private int retryAttempts;

    #endregion

    #region Constructors

    public CloudSyncControl(CloudTransportStore transport, IClock clock, Func<bool> seedIsDisposable) {
        ArgumentNullException.ThrowIfNull(transport);
        ArgumentNullException.ThrowIfNull(clock);
        ArgumentNullException.ThrowIfNull(seedIsDisposable);
        this.transport = transport;
        this.clock = clock;
        this.seedIsDisposable = seedIsDisposable;
    }

    #endregion

    #region Actions - Intents

    /// Runs one intent and answers the status it left with the steps the
    /// platform takes next. Throws `Rejected` when the transport's state
    /// cannot be saved.
    public IReadOnlyList<Change> Handle(CloudSyncControlIntent intent) {
        ArgumentNullException.ThrowIfNull(intent);
        lock (gate) {
            var steps = intent switch {
                ConfigureCloudSync configure => Configure(configure),
                SetCloudSyncEnabled enabling => SetEnabled(enabling.IsEnabled),
                StartCloudSync => Start(),
                RequestCloudSync => SyncNow(),
                RequestCloudPull => Pull(),
                ChooseCloudCopy choice => Choose(choice.UsesCloud),
                NotifyCloudLocalChanges => enabled && conflict is null && transportLive ? [Step(CloudSyncStepKind.NotifyTransport)] : [],
                ObserveCloudAccountAvailability => AccountAvailabilityChanged(),
                RetryCloudSync => RetryDue(),
                RestartCloudSyncAfterAccountChange => RestartDue(),
                CloudEntitlementChecked checkedEntitlement => EntitlementChecked(checkedEntitlement),
                CloudAccountChecked checkedAccount => AccountChecked(checkedAccount),
                CloudSeedReplaced replaced => SeedReplaced(replaced),
                CloudContentCompared compared => ContentCompared(compared),
                CloudContentTaken taken => ResetThenStart(taken.Attempt, overwritesCloud: false),
                CloudCopyApplied applied => CopyApplied(applied),
                CloudTransportStarted started => TransportStarted(started.Attempt),
                CloudTransportSynced synced => Synced(synced),
                CloudTransportPulled pulled => Pulled(pulled),
                CloudStepFailed failed => StepFailed(failed),
                CloudTransportReported report => Reported(report),
                _ => throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "Sync control does not handle this intent.")
            };
            return [new CloudSyncAdvanced(Status(), steps)];
        }
    }

    private List<CloudSyncStep> Configure(ConfigureCloudSync configure) {
        enabled = configure.IsEnabled;
        canReachCloud = configure.CanReachCloud;
        phase = enabled ? CloudSyncPhase.Checking : CloudSyncPhase.Disabled;
        return [];
    }

    /// Turning sync on starts it, once a start under way ends; turning it off
    /// drops the transport and starts its state over, keeping an account
    /// decision that waits.
    private List<CloudSyncStep> SetEnabled(bool value) {
        if (enabled == value) return [];
        enabled = value;
        if (enabled) {
            if (running) {
                accountRestartRequested = true;
                return [];
            }
            return Start();
        }
        attempt++;
        var steps = CancelRetry();
        if (transportLive) {
            transportLive = false;
            steps.Add(Step(CloudSyncStepKind.StopTransport));
        }
        conflict = null;
        accountRestartRequested = false;
        phase = CloudSyncPhase.Disabled;
        ClearFailure();
        try {
            transport.ResetUnlessAwaitingDecision();
        } catch (Rejected) {
            // The next start starts over from what was kept.
        }
        return steps;
    }

    /// Checks the entitlement, the account, the seed and a waiting account
    /// decision, in that order, then starts the transport.
    private List<CloudSyncStep> Start() {
        if (!enabled || running || transportLive) return [];
        running = true;
        attempt++;
        if (!canReachCloud) {
            phase = CloudSyncPhase.Failed;
            problem = CloudSyncProblem.NotConfigured;
            failureMessage = null;
            account = CloudAccountState.CouldNotDetermine;
            return Finish();
        }
        return [Step(CloudSyncStepKind.CheckEntitlement)];
    }

    private List<CloudSyncStep> EntitlementChecked(CloudEntitlementChecked result) {
        if (!Current(result.Attempt)) return Finish();
        if (!result.Granted) {
            phase = CloudSyncPhase.Failed;
            problem = CloudSyncProblem.EntitlementMissing;
            failureMessage = null;
            account = CloudAccountState.CouldNotDetermine;
            return Finish();
        }
        phase = CloudSyncPhase.Checking;
        ClearFailure();
        lastAttemptAt = clock.Now;
        return [Step(CloudSyncStepKind.CheckAccount)];
    }

    private List<CloudSyncStep> AccountChecked(CloudAccountChecked result) {
        if (!Current(result.Attempt)) return Finish();
        account = result.State;
        if (account != CloudAccountState.Available) {
            phase = CloudSyncPhase.WaitingForAccount;
            return Finish();
        }
        return seedIsDisposable() ? [Step(CloudSyncStepKind.ReplaceSeed)] : AfterSeed(result.Attempt);
    }

    /// The first launch took the cloud's content in place of its seed, so the
    /// transport starts over from it.
    private List<CloudSyncStep> SeedReplaced(CloudSeedReplaced result) {
        observedCloud = result.CloudRecords;
        if (!Reset(overwritesCloud: false, result.Attempt)) return Finish();
        return AfterSeed(result.Attempt);
    }

    /// With an account decision waiting, this device's content is compared
    /// with the cloud's first.
    private List<CloudSyncStep> AfterSeed(long start) {
        if (!Current(start)) return Finish();
        return transport.AwaitsAccountDecision ? [Step(CloudSyncStepKind.CompareContent)] : StartTransport();
    }

    /// Content that differs pauses for the person; a device with nothing takes
    /// the cloud's; otherwise the transport starts over.
    private List<CloudSyncStep> ContentCompared(CloudContentCompared result) {
        if (!Current(result.Attempt)) return Finish();
        observedCloud = result.CloudRecords;
        var comparison = result.Comparison;
        if (comparison.DeviceRecords > 0 && !comparison.Matches) {
            conflict = comparison;
            phase = CloudSyncPhase.NeedsReconciliation;
            return Finish();
        }
        if (comparison.DeviceRecords == 0 && comparison.CloudRecords > 0) return [Step(CloudSyncStepKind.TakeCloudContent)];
        return ResetThenStart(result.Attempt, overwritesCloud: false);
    }

    /// The transport starts over once this device took content; a start
    /// that is no longer current starts no transport.
    private List<CloudSyncStep> ResetThenStart(long start, bool overwritesCloud) {
        if (!Reset(overwritesCloud, start) || !Current(start)) return Finish();
        return StartTransport();
    }

    /// Starts the transport unless one is already live. The start ends once
    /// it reports.
    private List<CloudSyncStep> StartTransport() {
        if (transportLive) return Finish();
        transportLive = true;
        return [Step(CloudSyncStepKind.StartTransport)];
    }

    private List<CloudSyncStep> TransportStarted(long start) {
        var steps = Current(start) ? [] : new List<CloudSyncStep> { Step(CloudSyncStepKind.DiscardStartedTransport, start) };
        steps.AddRange(Finish());
        return steps;
    }

    /// Has the running transport sync now, or starts sync when none runs.
    private List<CloudSyncStep> SyncNow() {
        if (!enabled || conflict is not null || running) return [];
        if (!transportLive) return Start();
        running = true;
        lastAttemptAt = clock.Now;
        phase = CloudSyncPhase.Syncing;
        return [Step(CloudSyncStepKind.SyncTransport)];
    }

    private List<CloudSyncStep> Synced(CloudTransportSynced result) {
        if (!Current(result.Attempt) || accountRestartRequested) return Finish();
        if (conflict is not null) {
            phase = CloudSyncPhase.NeedsReconciliation;
            return Finish();
        }
        var steps = RecordSuccess(result.LocalChangesUnsaved);
        steps.AddRange(Finish());
        return steps;
    }

    /// Pulls a full snapshot through the running transport.
    private List<CloudSyncStep> Pull() {
        if (!enabled || conflict is not null || running || account != CloudAccountState.Available || !transportLive) return [];
        running = true;
        lastAttemptAt = clock.Now;
        phase = CloudSyncPhase.Syncing;
        return [Step(CloudSyncStepKind.PullTransport)];
    }

    private List<CloudSyncStep> Pulled(CloudTransportPulled result) {
        if (!Current(result.Attempt) || accountRestartRequested) return Finish();
        observedCloud = result.CloudRecords;
        lastFetched = result.CloudRecords;
        skipped = 0;
        requiresAppUpdate = false;
        var steps = RecordSuccess(result.LocalChangesUnsaved);
        steps.AddRange(Finish());
        return steps;
    }

    /// Applies the copy the person chose, then starts the transport over it.
    private List<CloudSyncStep> Choose(bool usesCloud) {
        if (!enabled || conflict is null || !canReachCloud || running) return [];
        running = true;
        attempt++;
        phase = CloudSyncPhase.Syncing;
        lastAttemptAt = clock.Now;
        return [new CloudSyncStep(CloudSyncStepKind.ApplyChosenCopy, attempt, usesCloud)];
    }

    /// The transport starts over from the chosen copy: this device's
    /// overwrites the cloud's until everything it staged has uploaded.
    private List<CloudSyncStep> CopyApplied(CloudCopyApplied result) {
        if (!Current(result.Attempt)) return Finish();
        observedCloud = result.CloudRecords;
        if (!Reset(overwritesCloud: !result.UsesCloud, result.Attempt)) return Finish();
        transportLive = false;
        conflict = null;
        return StartTransport();
    }

    /// A failed step fails the start, sync, pull or choice it belonged to.
    private List<CloudSyncStep> StepFailed(CloudStepFailed failed) {
        if (failed.Step == CloudSyncStepKind.StartTransport && Current(failed.Attempt)) transportLive = false;
        if (!Current(failed.Attempt)) return Finish();
        if (failed.ObservedCloudRecords is { } observed) observedCloud = observed;
        Fail(failed.Message);
        return Finish();
    }

    /// What the running transport reported of itself.
    private List<CloudSyncStep> Reported(CloudTransportReported report) {
        if (!Current(report.Attempt)) return [];
        var kind = report.Report;
        if (kind == CloudTransportReport.Fetched || kind == CloudTransportReport.Uploaded) {
            if (kind == CloudTransportReport.Fetched) lastFetched = report.RecordCount;
            else lastUploaded = report.RecordCount;
            lastSuccessAt = clock.Now;
            return ClearRecoveredFailure();
        }
        if (kind == CloudTransportReport.AccountChanged) {
            // The transport restarts against the account signed in now.
            transportLive = false;
            attempt++;
            conflict = null;
            accountRestartRequested = true;
            phase = CloudSyncPhase.Checking;
            var steps = new List<CloudSyncStep> { Step(CloudSyncStepKind.StopTransport) };
            steps.AddRange(AccountRestartIfDue());
            return steps;
        }
        if (kind == CloudTransportReport.SkippedRecords) {
            skipped += report.RecordCount;
            requiresAppUpdate |= report.RequiresAppUpdate;
            return [];
        }
        if (kind == CloudTransportReport.CloudDataRemoved) {
            cloudDataRemoved = true;
            return [];
        }
        // A status: while the person decides, the transport does not speak.
        if (conflict is not null) return [];
        if (kind == CloudTransportReport.Stopped) phase = enabled ? CloudSyncPhase.Checking : CloudSyncPhase.Disabled;
        else if (kind == CloudTransportReport.Syncing) phase = CloudSyncPhase.Syncing;
        else if (kind == CloudTransportReport.PausedForAccountConfirmation) phase = CloudSyncPhase.NeedsReconciliation;
        else if (kind == CloudTransportReport.Failed) Fail(report.Message ?? string.Empty);
        else if (kind == CloudTransportReport.Idle) {
            phase = CloudSyncPhase.Ready;
            return ClearRecoveredFailure();
        }
        return [];
    }

    /// Starts over against whichever account is signed in now.
    private List<CloudSyncStep> AccountAvailabilityChanged() {
        var steps = CancelRetry();
        retryAttempts = 0;
        attempt++;
        if (transportLive) {
            transportLive = false;
            steps.Add(Step(CloudSyncStepKind.StopTransport));
        }
        conflict = null;
        accountRestartRequested = running;
        if (!enabled) return steps;
        phase = CloudSyncPhase.Checking;
        steps.AddRange(Start());
        return steps;
    }

    private List<CloudSyncStep> RetryDue() {
        retryScheduled = false;
        if (!enabled || conflict is not null || running) return [];
        return SyncNow();
    }

    private List<CloudSyncStep> RestartDue() {
        if (!accountRestartRequested || running) return [];
        accountRestartRequested = false;
        return Start();
    }

    #endregion

    #region Actions - Outcomes

    /// A sync that finished counts as a success unless this device's own
    /// edits could not be staged or saved meanwhile.
    private List<CloudSyncStep> RecordSuccess(bool localChangesUnsaved) {
        if (localChangesUnsaved) {
            phase = CloudSyncPhase.Failed;
            problem = CloudSyncProblem.LocalChangesUnsaved;
            failureMessage = null;
            return [];
        }
        lastSuccessAt = clock.Now;
        phase = CloudSyncPhase.Ready;
        ClearFailure();
        retryAttempts = 0;
        return CancelRetry();
    }

    /// Activity from a transport the system scheduler retried proves that
    /// it recovered, so an earlier error must not stay.
    private List<CloudSyncStep> ClearRecoveredFailure() {
        if (running || !HasError) return [];
        phase = CloudSyncPhase.Ready;
        ClearFailure();
        retryAttempts = 0;
        return CancelRetry();
    }

    private void Fail(string message) {
        failureMessage = message;
        problem = null;
        phase = CloudSyncPhase.Failed;
    }

    private void ClearFailure() {
        problem = null;
        failureMessage = null;
    }

    private bool HasError => failureMessage is not null || problem is { ReportsError: true };

    /// Starts the transport's state over; a save that fails fails `start`
    /// while it is current.
    private bool Reset(bool overwritesCloud, long start) {
        try {
            transport.Reset(overwritesCloud);
            return true;
        } catch (Rejected rejected) {
            if (Current(start)) Fail(rejected.Rejection is SaveFailed failed ? failed.Message : rejected.Rejection.GetType().Name);
            return false;
        }
    }

    /// What ending a start, sync, pull or choice leads to: a restart an
    /// account change asked for, or a retry of a launch that could not reach
    /// iCloud.
    private List<CloudSyncStep> Finish() {
        running = false;
        var steps = AccountRestartIfDue();
        steps.AddRange(RetryIfDue());
        return steps;
    }

    private List<CloudSyncStep> AccountRestartIfDue() =>
        accountRestartRequested && !running ? [Step(CloudSyncStepKind.RestartAfterAccountChange)] : [];

    /// Retries a launch that ended without a working transport, a few times.
    private List<CloudSyncStep> RetryIfDue() {
        if (!enabled || conflict is not null || running || accountRestartRequested || transportLive || !canReachCloud
            || retryScheduled || retryAttempts >= MaximumRetryAttempts || !phase.IsRetryable) return [];
        retryAttempts++;
        retryScheduled = true;
        return [Step(CloudSyncStepKind.ScheduleRetry)];
    }

    private List<CloudSyncStep> CancelRetry() {
        if (!retryScheduled) return [];
        retryScheduled = false;
        return [Step(CloudSyncStepKind.CancelRetry)];
    }

    private bool Current(long start) => enabled && start == attempt;

    private CloudSyncStep Step(CloudSyncStepKind kind) => new(kind, attempt, UsesCloud: false);

    private static CloudSyncStep Step(CloudSyncStepKind kind, long start) => new(kind, start, UsesCloud: false);

    #endregion

    #region Actions - Queries

    public CloudSyncStatus Answer(CloudSync query) {
        ArgumentNullException.ThrowIfNull(query);
        lock (gate) return Status();
    }

    private CloudSyncStatus Status() => new(enabled, account, phase, problem, failureMessage, lastAttemptAt, lastSuccessAt, lastFetched,
        lastUploaded, observedCloud, conflict, skipped, requiresAppUpdate, cloudDataRemoved);

    #endregion
}
