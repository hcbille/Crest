using CrestCore.Application;

namespace CrestCore.Contracts;

/// The transport started for `Attempt` reported `Report`: `Message` carries a
/// failure's words, `RecordCount` counts a batch or the skipped records, and
/// `RequiresAppUpdate` tells whether a newer build wrote records it skipped.
public sealed record CloudTransportReported(long Attempt, CloudTransportReport Report, string? Message, int RecordCount,
    bool RequiresAppUpdate) : CloudSyncControlIntent {
    #region Actions - Sync

    /// What the running transport reported of itself.
    internal override List<CloudSyncStep> Steps(CloudSyncControl control) {
        if (!control.Current(Attempt)) return [];
        var kind = Report;
        if (kind == CloudTransportReport.Fetched || kind == CloudTransportReport.Uploaded) {
            if (kind == CloudTransportReport.Fetched) control.LastFetched = RecordCount;
            else control.LastUploaded = RecordCount;
            control.LastSuccessAt = control.Clock.Now;
            return control.ClearRecoveredFailure();
        }
        if (kind == CloudTransportReport.AccountChanged) {
            // The transport restarts against the account signed in now.
            control.IsTransportLive = false;
            control.Attempt++;
            control.Conflict = null;
            control.AccountRestartRequested = true;
            control.Phase = CloudSyncPhase.Checking;
            var steps = new List<CloudSyncStep> { control.Step(CloudSyncStepKind.StopTransport) };
            steps.AddRange(control.AccountRestartIfDue());
            return steps;
        }
        if (kind == CloudTransportReport.SkippedRecords) {
            control.Skipped += RecordCount;
            control.RequiresAppUpdate |= RequiresAppUpdate;
            return [];
        }
        if (kind == CloudTransportReport.CloudDataRemoved) {
            control.CloudDataRemoved = true;
            return [];
        }
        // A status: while the person decides, the transport does not speak.
        if (control.Conflict is not null) return [];
        if (kind == CloudTransportReport.Stopped) control.Phase = control.IsEnabled ? CloudSyncPhase.Checking : CloudSyncPhase.Disabled;
        else if (kind == CloudTransportReport.Syncing) control.Phase = CloudSyncPhase.Syncing;
        else if (kind == CloudTransportReport.PausedForAccountConfirmation) control.Phase = CloudSyncPhase.NeedsReconciliation;
        else if (kind == CloudTransportReport.Failed) control.Fail(Message ?? string.Empty);
        else if (kind == CloudTransportReport.Idle) {
            control.Phase = CloudSyncPhase.Ready;
            return control.ClearRecoveredFailure();
        }
        return [];
    }

    #endregion
}
