using CrestCore.Application;
using CrestCore.Contracts;

using Xunit;

namespace CrestCore.Tests;

/// Closing asks each page it would close whether it may go, one at a time: the
/// first that asks to stay ends it not allowed, a page that goes has nothing to
/// ask, a page that shows another document after agreeing voids the answer, and
/// quitting with downloads in progress asks the person.
public sealed partial class BrowserContractsTests {
    [Fact]
    public void ClosingAsksEachPageInTurnAndTheFirstThatStaysEndsItNotAllowed() {
        var (app, engine, binding, page, workspace, window, space, _) = LivePage();
        using var disposal = app;
        var other = Guid.NewGuid();
        app.Send(new OpenPage(other, workspace, space, null, window));
        app.Report(engine, new PageCreated(other));
        app.Drain();

        var request = Guid.NewGuid();
        Assert.Empty(app.Send(new PrepareToClosePages(request, [page, other])));
        Assert.Equal(new CheckBeforeUnload(page), binding.Commands[^1]);
        Assert.Equal(new ClosePreparationUnderway(request), Refusal(app, new PrepareToQuit(Guid.NewGuid())));

        app.Report(engine, new BeforeUnloadAnswered(page, Proceeds: true));
        Assert.Equal(new CheckBeforeUnload(other), binding.Commands[^1]);
        app.Report(engine, new BeforeUnloadAnswered(other, Proceeds: false));
        Assert.Equal([new CloseReady(request, Allowed: false)], app.Drain());
    }

    [Fact]
    public void APageThatGoesHasNothingToAskAndOneThatMovesOnVoidsItsAnswer() {
        var (app, _, _, page, _, window, _, _) = LivePage();
        using var disposal = app;

        // The page waited on goes, so the window closes.
        var first = Guid.NewGuid();
        app.Send(new PrepareToCloseWindows(first, [window]));
        Assert.Contains(new CloseReady(first, Allowed: true), app.Send(new ReleasePage(page, KeepsState: false)));

        // A page that agreed, then showed another document, voids the answer.
        var (again, engineAgain, bindingAgain, pageAgain, _, _, _, _) = LivePage();
        using var disposalAgain = again;
        var second = Guid.NewGuid();
        again.Send(new PrepareToClosePages(second, [pageAgain]));
        again.Report(engineAgain, new NavigationCommitted(pageAgain, "https://example.org/", SameDocument: false));
        again.Report(engineAgain, new BeforeUnloadAnswered(pageAgain, Proceeds: true));
        Assert.Contains(new CloseReady(second, Allowed: false), again.Drain());
        Assert.Equal(new CheckBeforeUnload(pageAgain), bindingAgain.Commands[^1]);
    }

    [Fact]
    public void QuittingWithDownloadsInProgressAsksThePerson() {
        var (app, engine, _, page, workspace, _, space, _) = LivePage();
        using var disposal = app;
        var profile = ProfileOf(app, workspace, space);
        app.Report(engine, new EngineDownloadChanged(Transfer(profile, page, EngineDownloadState.Downloading, received: 10)));
        app.Drain();

        var request = Guid.NewGuid();
        app.Send(new PrepareToQuit(request));
        app.Report(engine, new BeforeUnloadAnswered(page, Proceeds: true));
        var asked = Assert.IsType<QuitWithDownloadsAsked>(Assert.Single(app.Drain()));
        Assert.Equal((request, 1), (asked.RequestId, asked.LiveDownloads));
        Assert.Equal([new PromptSettled(asked.PromptId), new CloseReady(request, Allowed: true)],
            app.Send(new AnswerQuitWithDownloads(asked.PromptId, Quits: true)));
    }
}
