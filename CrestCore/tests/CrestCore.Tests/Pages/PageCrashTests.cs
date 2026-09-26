using CrestCore.Application;
using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

/// A page whose renderer stopped comes back by the core's budget: a page on
/// screen reloads at once, one nobody sees reloads once it is shown, and past
/// the budget the failure stays until the person asks for the page again.
public sealed partial class BrowserContractsTests {
    private static PageCrashed Crashed(Guid page) => new(page, "ChromiumTerminationStatus", 3);

    private static int Recoveries(RecordingEngine binding, Guid page) =>
        binding.Commands.Count(command => command == new RecoverPage(page));

    [Fact]
    public void APageOnScreenReloadsWithinTheBudgetAndThenShowsTheFailure() {
        var (app, engine, binding, page, _, window, space, tab) = LivePage();
        using var disposal = app;
        app.Send(new ShowTab(window, space, tab));
        app.Report(engine, new PageStateChanged(page, Showing("https://example.com/", "Example")));
        app.Drain();

        // Each crash within the budget reloads the page at once, and shows no failure.
        for (var crash = 1; crash <= PageProcessRecoveryPolicy.MaximumAutomaticReloads; crash++) {
            app.Report(engine, Crashed(page));
            Assert.Equal(crash, Recoveries(binding, page));
            Assert.Empty(app.Drain());
        }

        // The next one shows the failure over the document it replaced, and reloads nothing.
        app.Report(engine, Crashed(page));
        var stopped = Live(app.Drain());
        Assert.Equal(PageProcessRecoveryPolicy.MaximumAutomaticReloads, Recoveries(binding, page));
        Assert.Equal(new PageFailure(NavigationError.WebContentProcessStopped, "https://example.com/", ReplacedDocument: true,
            "ChromiumTerminationStatus", 3), stopped.Failure);

        // A document that finishes loading starts the budget over.
        app.Report(engine, new NavigationCommitted(page, "https://example.com/", SameDocument: false));
        app.Report(engine, new NavigationFinished(page, "https://example.com/", "Example"));
        app.Drain();
        app.Report(engine, Crashed(page));
        Assert.Equal(PageProcessRecoveryPolicy.MaximumAutomaticReloads + 1, Recoveries(binding, page));
    }

    [Fact]
    public void APageNobodySeesShowsTheFailureAndReloadsOnceItIsShown() {
        var (app, engine, binding, page, _, window, space, tab) = LivePage();
        using var disposal = app;
        app.Send(new ShowTab(window, space, null));
        app.Report(engine, new PageStateChanged(page, Showing("https://example.com/", "Example")));
        app.Drain();

        app.Report(engine, Crashed(page));
        Assert.Equal(NavigationError.WebContentProcessStopped, Live(app.Drain()).Failure?.Error);
        Assert.Equal(0, Recoveries(binding, page));

        // Showing nothing brings nothing back; showing the page's tab does, once.
        app.Send(new ShowTab(window, space, null));
        Assert.Equal(0, Recoveries(binding, page));
        app.Send(new ShowTab(window, space, tab));
        app.Send(new ShowTab(window, space, tab));
        Assert.Equal(1, Recoveries(binding, page));

        // The failure stays until the document the reload brings commits.
        app.Drain();
        app.Report(engine, new NavigationCommitted(page, "https://example.com/", SameDocument: false));
        Assert.Null(Live(app.Drain()).Failure);
    }

    [Fact]
    public void ACrashReportedForAPageThatIsNotLiveChangesNothing() {
        var (app, engine, binding, _, workspace, window, space, _) = LivePage();
        using var disposal = app;
        var opening = Guid.NewGuid();
        app.Send(new OpenPage(opening, workspace, space, null, window));
        app.Drain();
        app.Report(engine, Crashed(opening));
        app.Report(engine, Crashed(Guid.NewGuid()));
        Assert.Empty(app.Drain());
        Assert.Equal(0, Recoveries(binding, opening));
    }
}
