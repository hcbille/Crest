using CrestCore.Application;
using CrestCore.Contracts;

using Xunit;

namespace CrestCore.Tests;

/// The protected media fallback: a page whose engine cannot play the key
/// system it asked for moves, once, to an engine that plays protected media
/// through the platform, and its site opens there from then on, unless the
/// person chose an engine for it.
public sealed partial class BrowserContractsTests {
    /// A live page of the fixture tab on a default Chromium binding, with a
    /// WebKit binding beside it that plays protected media when `webKitPlays`.
    private static (CrestApp App, Engine Chromium, RecordingEngine ChromiumBinding, Engine WebKit, RecordingEngine WebKitBinding,
        Guid Page, Guid Workspace, Guid Window, Guid Space, Guid Tab) ChromiumPage(bool webKitPlays = true) {
        var fixture = SavedSession();
        var app = new CrestApp();
        var (chromiumBinding, webKitBinding) = (new RecordingEngine(), new RecordingEngine());
        var chromium = app.RegisterEngine(new EngineRegistration(EngineKind.Chromium, EngineCapability.Required, IsDefault: true),
            chromiumBinding.Run);
        var webKit = app.RegisterEngine(new EngineRegistration(EngineKind.WebKit,
            webKitPlays ? [.. EngineCapability.Required, EngineCapability.ProtectedMedia] : EngineCapability.Required, IsDefault: false),
            webKitBinding.Run);
        var workspace = TestWorkspaces.Open(app, fixture.Document["session"]!);
        var window = Guid.NewGuid();
        app.Send(new OpenWindow(window, workspace, Saved: false, null, null, [], RestoresTabs: true));
        var page = Guid.NewGuid();
        app.Send(new OpenPage(page, workspace, fixture.Space, fixture.Tab, window));
        app.Report(chromium, new PageCreated(page));
        app.Report(chromium, new NavigationCommitted(page, TabUrl(app, workspace, fixture.Space, fixture.Tab), SameDocument: false));
        app.Drain();
        return (app, chromium, chromiumBinding, webKit, webKitBinding, page, workspace, window, fixture.Space, fixture.Tab);
    }

    private static string TabUrl(CrestApp app, Guid workspace, Guid space, Guid tab) =>
        app.Workspace(workspace).Current.Spaces.Single(held => held.Id == space).Tabs.Single(held => held.Id == tab).Url!;

    [Fact]
    public void APageMovesOnceToAnEngineThatPlaysProtectedMediaAndItsSiteOpensThere() {
        var (app, chromium, chromiumBinding, webKit, webKitBinding, page, workspace, window, space, tab) = ChromiumPage();
        using var disposal = app;
        var url = TabUrl(app, workspace, space, tab);
        var site = new WebAddress(url).Origin!;

        app.Report(chromium, new ProtectedMediaUnavailable(page, KeySystem.Widevine));
        var moved = app.Drain();
        Assert.Equal(new PageRehosted(page, space, site, EngineKind.Chromium, EngineKind.WebKit, RehostReason.ProtectedMedia),
            Assert.Single(moved.OfType<PageRehosted>()));
        Assert.Equal(EngineKind.WebKit, Assert.Single(moved.OfType<PageChanged>()).Page.Engine);
        Assert.Equal(new ClosePage(page, KeepsState: false), chromiumBinding.Commands[^1]);
        app.Report(webKit, new PageCreated(page));
        Assert.Equal(new LoadPage(page, url), webKitBinding.Commands[^1]);

        // A repeat from the engine it left changes nothing, and the site's next page opens on WebKit directly.
        app.Report(chromium, new ProtectedMediaUnavailable(page, KeySystem.Widevine));
        Assert.Empty(app.Drain().OfType<PageRehosted>());
        app.Send(new ReleasePage(page, KeepsState: false));
        var next = Guid.NewGuid();
        app.Send(new OpenPage(next, workspace, space, tab, window));
        Assert.Equal(next, Assert.IsType<CreatePage>(webKitBinding.Commands[^1]).PageId);
    }

    [Fact]
    public void AMovedBackPageNeverBouncesAndItsSiteStaysWhereThePersonChose() {
        var (app, chromium, chromiumBinding, webKit, _, page, workspace, window, space, tab) = ChromiumPage();
        using var disposal = app;
        var site = new WebAddress(TabUrl(app, workspace, space, tab)).Origin!;
        app.Report(chromium, new ProtectedMediaUnavailable(page, KeySystem.PlayReady));
        app.Report(webKit, new PageCreated(page));

        // Moving back records the person's engine for the site and moves the page there.
        app.Send(new ChooseSiteEngine(space, site, EngineKind.Chromium));
        var back = app.Send(new RehostPage(page, EngineKind.Chromium));
        Assert.Equal(RehostReason.PersonAsked, Assert.Single(back.OfType<PageRehosted>()).Reason);
        app.Report(chromium, new PageCreated(page));
        app.Drain();

        // The page asks again on Chromium, and stays.
        int commands = chromiumBinding.Commands.Count;
        app.Report(chromium, new ProtectedMediaUnavailable(page, KeySystem.PlayReady));
        Assert.Empty(app.Drain().OfType<PageRehosted>());
        Assert.Equal(commands, chromiumBinding.Commands.Count);

        // So does the site's next page, which the person's choice keeps on Chromium.
        app.Send(new ReleasePage(page, KeepsState: false));
        var next = Guid.NewGuid();
        app.Send(new OpenPage(next, workspace, space, tab, window));
        app.Report(chromium, new PageCreated(next));
        app.Report(chromium, new NavigationCommitted(next, TabUrl(app, workspace, space, tab), SameDocument: false));
        app.Report(chromium, new ProtectedMediaUnavailable(next, KeySystem.Widevine));
        Assert.Empty(app.Drain().OfType<PageRehosted>());
        Assert.Equal(next, Assert.IsType<CreatePage>(chromiumBinding.Commands[^1]).PageId);
    }

    [Fact]
    public void NothingMovesWithoutAnEngineThatPlaysProtectedMedia() {
        var (app, chromium, chromiumBinding, _, webKitBinding, page, _, _, _, _) = ChromiumPage(webKitPlays: false);
        using var disposal = app;
        int commands = chromiumBinding.Commands.Count;

        app.Report(chromium, new ProtectedMediaUnavailable(page, KeySystem.Widevine));

        Assert.Empty(app.Drain());
        Assert.Equal(commands, chromiumBinding.Commands.Count);
        Assert.Empty(webKitBinding.Commands);
    }
}
