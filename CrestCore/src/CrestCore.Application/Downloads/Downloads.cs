using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The downloads area: this run's download ledger and the changes each
/// download intent publishes. An event that does not apply to a record's
/// phase publishes nothing. Nothing here is persisted or synced.
internal sealed class Downloads : IDownloadIntentHandler<ChangeFeed> {
    #region Variables

    private readonly DownloadLedger ledger = new();

    #endregion

    #region Actions - Intents

    public void Handle(DownloadIntent intent, ChangeFeed changes) => intent.Dispatch(this, changes);

    public void Handle(BeginDownload begin, ChangeFeed changes) =>
        Updated(ledger.Begin(begin.DownloadId, begin.ProfileId, begin.Filename, begin.CreatedAt, begin.IsAcknowledged), changes);

    public void Handle(SetDownloadDestination destination, ChangeFeed changes) =>
        Updated(ledger.SetDestination(destination.DownloadId, destination.Destination, destination.Filename), changes);

    public void Handle(RecordDownloadTransfer transfer, ChangeFeed changes) =>
        Updated(ledger.RecordTransfer(transfer.DownloadId, transfer.Telemetry, transfer.Progress), changes);

    public void Handle(AssessDownloadRisk risk, ChangeFeed changes) => Updated(ledger.AssessRisk(risk.DownloadId, risk.Assessment), changes);

    public void Handle(AwaitDownloadApproval approval, ChangeFeed changes) => Updated(ledger.AwaitApproval(approval.DownloadId), changes);

    public void Handle(FinishDownload finish, ChangeFeed changes) => Updated(ledger.Finish(finish.DownloadId, finish.FinalByteCount), changes);

    public void Handle(FailDownload failure, ChangeFeed changes) =>
        Updated(ledger.Fail(failure.DownloadId, failure.Reason, failure.Message), changes);

    public void Handle(CancelDownload cancellation, ChangeFeed changes) =>
        Updated(ledger.Cancel(cancellation.DownloadId, cancellation.Message), changes);

    public void Handle(BlockAutomaticDownload block, ChangeFeed changes) => Updated(ledger.BlockAutomaticDownload(block.DownloadId), changes);

    public void Handle(RestartDownload restart, ChangeFeed changes) => Updated(ledger.Restart(restart.DownloadId), changes);

    public void Handle(AcknowledgeDownloads acknowledgement, ChangeFeed changes) {
        foreach (var download in ledger.AcknowledgeProfile(acknowledgement.ProfileId)) Updated(download, changes);
    }

    public void Handle(RemoveDownload removal, ChangeFeed changes) =>
        Removed(ledger.Remove(removal.DownloadId) ? [removal.DownloadId] : [], changes);

    public void Handle(RemoveProfileDownloads profileRemoval, ChangeFeed changes) => Removed(ledger.RemoveProfile(profileRemoval.ProfileId), changes);

    public void Handle(ExpireDownloads expiry, ChangeFeed changes) => Removed(ledger.RemoveExpired(expiry.Retentions, expiry.Now), changes);

    private void Updated(DownloadState? download, ChangeFeed changes) {
        if (download is not null) changes.Publish(new DownloadUpdated(download, ledger.IndexOf(download.Id)));
    }

    private static void Removed(IReadOnlyList<Guid> downloadIds, ChangeFeed changes) {
        if (downloadIds.Count > 0) changes.Publish(new DownloadsRemoved(downloadIds));
    }

    #endregion

    #region Actions - Queries

    /// How many downloads are still in progress.
    public int LiveCount => ledger.Items.Count(download => download.Phase.IsLive);

    public DownloadProgressReading Answer(DownloadProgress query) {
        ArgumentNullException.ThrowIfNull(query);
        return (query.Estimator ?? DownloadTransferEstimator.Initial).Sample(query.CompletedUnitCount, query.TotalUnitCount,
            query.FractionCompleted, query.IsPaused, query.Uptime);
    }

    public DownloadRiskVerdict Answer(DownloadRisk query) {
        ArgumentNullException.ThrowIfNull(query);
        var assessment = DownloadRiskAssessment.Of(query.Facts);
        return new(assessment, assessment.RequiresConfirmation(query.IsUserInitiated));
    }

    #endregion
}
