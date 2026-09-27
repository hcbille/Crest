using CrestCore.Application;

namespace CrestCore.Contracts;

/// Whether the person keeps a file the engine warned about. A file not kept
/// is cancelled.
public sealed record AnswerDownloadApproval(Guid PromptId, bool Approved) : PromptIntent(PromptId) {
    #region Actions - Downloads

    /// A file the person does not keep is cancelled at once. One they go on
    /// with despite the core's reasons is then asked where it goes, and one
    /// they keep despite its engine's warning goes on.
    internal override void Apply(CrestApp app, ChangeFeed changes) {
        var engineDownloads = app.EngineDownloads;
        var prompt = engineDownloads.Prompt(PromptId);
        var download = prompt.Download;
        if (prompt.Question == EngineDownloads.Question.Risk) {
            engineDownloads.Settle(PromptId, changes);
            var held = prompt.Held!;
            if (Approved && engineDownloads.SpaceOf(held.Download) is { } space) {
                download.ReasonsApproved = true;
                engineDownloads.AskDestination(download, held, space, changes);
            } else {
                app.Issue(download.Engine, new SettleDownloadDestination(held.PromptId, Path: null));
                engineDownloads.Record(new CancelDownload(download.DownloadId,
                    Approved ? EngineDownloads.CanceledMessage : EngineDownloads.DeclinedMessage), changes);
                engineDownloads.End(download, changes);
            }
        } else if (prompt.Question == EngineDownloads.Question.Approval) {
            engineDownloads.Settle(PromptId, changes);
            if (Approved) {
                app.Issue(download.Engine, new ApproveEngineDownload(download.ProfileId, download.EngineId, download.ApprovalToken ?? ""));
            } else {
                app.Issue(download.Engine, new CancelEngineDownload(download.ProfileId, download.EngineId));
                engineDownloads.Record(new CancelDownload(download.DownloadId, EngineDownloads.CanceledMessage), changes);
                engineDownloads.End(download, changes);
            }
        } else {
            throw new Rejected(new PromptAnswerMismatch(PromptId));
        }
    }

    #endregion
}
