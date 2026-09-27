using CrestCore.Application;

namespace CrestCore.Contracts;

/// Where the file of a download goes, as the platform resolved it or the person
/// chose it, or none to cancel the download.
public sealed record AnswerDownloadDestination(Guid PromptId, string? Path) : PromptIntent(PromptId) {
    #region Actions - Downloads

    /// A file going somewhere names the record's file.
    internal override void Apply(CrestApp app, ChangeFeed changes) {
        var engineDownloads = app.EngineDownloads;
        var prompt = engineDownloads.Prompt(PromptId);
        if (prompt.Question != EngineDownloads.Question.Destination) throw new Rejected(new PromptAnswerMismatch(PromptId));
        var download = prompt.Download;
        engineDownloads.Settle(PromptId, changes);
        if (Path is { Length: > 0 } path && download.IsLive)
            engineDownloads.Record(new SetDownloadDestination(download.DownloadId, EngineDownloads.FileAddress(path),
                System.IO.Path.GetFileName(path)), changes);
        app.Issue(download.Engine, new SettleDownloadDestination(PromptId, Path));
    }

    #endregion
}
