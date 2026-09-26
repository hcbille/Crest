using CrestCore.Application;
using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

/// An engine's downloads in the core's ledger: each belongs to its page's
/// Space, where its file goes and keeping a file the engine warned about are
/// prompts, the person's row actions reach the engine, and a record's name
/// never carries characters that disguise the file.
public sealed partial class BrowserContractsTests {
    private static EngineDownload Transfer(Guid profile, Guid? page, EngineDownloadState state = EngineDownloadState.Preparing,
        long received = 0, long total = 100, EngineDownloadWarning? warning = null, string token = "",
        EngineDownloadInterruption? interruption = null, string? detail = null) =>
        new("7", profile, page, "report.pdf", Path: null, received, total, new DateTimeOffset(2026, 9, 25, 0, 0, 0, TimeSpan.Zero),
            Restored: false, Paused: false, state, warning, interruption, detail, token);

    private static Guid ProfileOf(CrestApp app, Guid workspace, Guid space) =>
        app.Workspace(workspace).Current.Spaces.First(candidate => candidate.Id == space).ProfileId;

    [Fact]
    public void AnEngineDownloadIsRecordedInItsPagesSpaceAndGoesWhereThePlatformAnswers() {
        var (app, engine, binding, page, workspace, _, space, _) = LivePage();
        using var disposal = app;
        var profile = ProfileOf(app, workspace, space);
        var prompt = Guid.NewGuid();

        app.Report(engine, new EngineDownloadDestinationRequested(prompt, Transfer(profile, page), "../report.pdf", ForcesPrompt: false));
        var asked = app.Drain();
        var record = Assert.IsType<DownloadUpdated>(asked[0]).Download;
        Assert.Equal((profile, "report.pdf", DownloadPhase.Preparing), (record.ProfileId, record.Filename, record.Phase));
        Assert.Equal(new DownloadDestinationAsked(prompt, record.Id, space, "report.pdf", ForcesPrompt: false), asked[^1]);

        var answered = app.Send(new AnswerDownloadDestination(prompt, "/Users/test/Downloads/report 2.pdf"));
        Assert.Equal("file:///Users/test/Downloads/report%202.pdf",
            answered.OfType<DownloadUpdated>().Single().Download.Destination);
        Assert.Contains(new PromptSettled(prompt), answered);
        Assert.Equal(new SettleDownloadDestination(prompt, "/Users/test/Downloads/report 2.pdf"), binding.Commands[^1]);

        app.Report(engine, new EngineDownloadChanged(Transfer(profile, page, EngineDownloadState.Downloading, received: 50)));
        Assert.Equal(0.5, app.Drain().OfType<DownloadUpdated>().Last().Download.Progress);
        app.Report(engine, new EngineDownloadChanged(Transfer(profile, page, EngineDownloadState.Finished, received: 100)));
        Assert.Equal(DownloadPhase.Finished, app.Drain().OfType<DownloadUpdated>().Last().Download.Phase);
    }

    [Fact]
    public void ADownloadNoSpaceCanHoldIsCancelledOnItsEngine() {
        var (app, engine, binding, _, _, _, _, _) = LivePage();
        using var disposal = app;
        var stranger = Guid.NewGuid();
        app.Report(engine, new EngineDownloadChanged(Transfer(stranger, page: null, EngineDownloadState.Downloading)));
        Assert.Empty(app.Drain());
        Assert.Equal(new CancelEngineDownload(stranger, "7"), binding.Commands[^1]);
    }

    [Fact]
    public void AWarnedDownloadAsksToBeKeptAndThePersonsRowActionsReachTheEngine() {
        var (app, engine, binding, page, workspace, _, space, _) = LivePage();
        using var disposal = app;
        var profile = ProfileOf(app, workspace, space);

        app.Report(engine, new EngineDownloadChanged(Transfer(profile, page, EngineDownloadState.AwaitingApproval,
            warning: EngineDownloadWarning.DangerousFile, token: "danger:file")));
        var asked = app.Drain();
        var record = asked.OfType<DownloadUpdated>().Last().Download;
        Assert.Equal(DownloadPhase.AwaitingApproval, record.Phase);
        var approval = Assert.IsType<DownloadApprovalAsked>(asked[^1]);
        Assert.Equal((record.Id, "report.pdf", EngineDownloadWarning.DangerousFile), (approval.DownloadId, approval.Filename, approval.Warning));
        Assert.Contains(new PromptSettled(approval.PromptId), app.Send(new AnswerDownloadApproval(approval.PromptId, Approved: true)));
        Assert.Equal(new ApproveEngineDownload(profile, "7", "danger:file"), binding.Commands[^1]);

        // The person cancels it from its row, then clears it; a late report brings nothing back.
        app.Send(new CancelDownload(record.Id, "Canceled."));
        Assert.Equal(new CancelEngineDownload(profile, "7"), binding.Commands[^1]);
        app.Send(new RemoveDownload(record.Id));
        Assert.Equal(new RemoveEngineDownload(profile, "7"), binding.Commands[^1]);
        app.Report(engine, new EngineDownloadChanged(Transfer(profile, page, EngineDownloadState.Downloading, received: 80)));
        Assert.Empty(app.Drain());
    }

    [Fact]
    public void AFailedDownloadRecordsWhyAsAReasonAndKeepsTheEnginesWordsAsItsMessage() {
        var (app, engine, _, page, workspace, _, space, _) = LivePage();
        using var disposal = app;
        var profile = ProfileOf(app, workspace, space);
        app.Report(engine, new EngineDownloadChanged(Transfer(profile, page, EngineDownloadState.Failed,
            interruption: EngineDownloadInterruption.NoSpace, detail: "Failed - Disk full")));
        var failed = app.Drain().OfType<DownloadUpdated>().Last().Download;
        Assert.Equal((DownloadPhase.Failed, DownloadFailure.NoSpace, "Failed - Disk full"), (failed.Phase, failed.Failure, failed.Message));

        // A download the engine blocked fails for its warning, with no words of its own.
        app.Report(engine, new EngineDownloadChanged(Transfer(profile, page, EngineDownloadState.Failed,
            warning: EngineDownloadWarning.InsecureBlocked) with { DownloadId = "8" }));
        var blocked = app.Drain().OfType<DownloadUpdated>().Last().Download;
        Assert.Equal((DownloadFailure.BlockedInsecure, (string?)null), (blocked.Failure, blocked.Message));
    }

    [Theory]
    [InlineData("folder/in‮exe.pdf", "inexe.pdf")]
    [InlineData("..\\secret​.txt..", "secret.txt")]
    [InlineData("a:b/c", "c")]
    [InlineData("  ", "download")]
    public void ADownloadsNameKeepsOnlyItsOwnSafeLastComponent(string suggested, string expected) {
        Assert.Equal(expected, DownloadFilename.Safe(suggested));
    }

    [Fact]
    public void ALongDownloadNameIsShortenedToWholeCharactersAndKeepsItsExtension() {
        var shortened = DownloadFilename.Safe(new string('é', 200) + ".pdf");
        Assert.EndsWith("é.pdf", shortened, StringComparison.Ordinal);
        Assert.True(System.Text.Encoding.UTF8.GetByteCount(shortened) <= DownloadFilename.MaximumByteCount);
    }
}
