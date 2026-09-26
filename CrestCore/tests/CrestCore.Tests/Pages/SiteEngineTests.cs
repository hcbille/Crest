using CrestCore.Application;
using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

/// Which engine a site's pages open on: the device store keeps the choices
/// made in the persistent session, every other Space's choices live in
/// memory, and a tab's page opens on the engine chosen for its site.
public sealed partial class BrowserContractsTests {
    private static SiteOrigin? Origin(TabState tab) => tab.Url is { } url ? new WebAddress(url).Origin : null;

    /// The engine of the `CreatePage` that opened `page`, by the binding that ran it.
    private static EngineKind CreatedOn(Guid page, RecordingEngine chromium, RecordingEngine webKit) =>
        chromium.Commands.OfType<CreatePage>().Any(command => command.PageId == page) ? EngineKind.Chromium
        : webKit.Commands.OfType<CreatePage>().Any(command => command.PageId == page) ? EngineKind.WebKit
        : throw new InvalidOperationException("No engine created the page.");

    [Fact]
    public void ATabsPageOpensOnTheEngineChosenForItsSiteAndOnlyThePersistentSessionsChoicesAreKept() {
        using var directory = new StorageDirectory();
        Guid spaceId, chosenTab, otherTab;
        SiteOrigin site;
        {
            var (app, workspace, _) = DeviceApp(directory);
            using var disposal = app;
            var (chromium, webKit) = (new RecordingEngine(), new RecordingEngine());
            var chromiumEngine = app.RegisterEngine(new EngineRegistration(EngineKind.Chromium, EngineCapability.Required, IsDefault: true),
                chromium.Run);
            app.RegisterEngine(new EngineRegistration(EngineKind.WebKit, EngineCapability.Required, IsDefault: false), webKit.Run);
            spaceId = app.Workspace(workspace).Current.Spaces.First(space => space.Settings.AccessPolicy == SpaceAccessPolicy.Open).Id;
            var window = Guid.NewGuid();
            app.Send(new OpenWindow(window, workspace, Saved: false, null, spaceId, [], RestoresTabs: true));
            foreach (var address in new[] { "https://video.example/watch", "https://news.example/today" })
                app.Send(new OpenAddress(workspace, window, spaceId, Guid.NewGuid(), address));
            var space = app.Workspace(workspace).Current.Spaces.Single(space => space.Id == spaceId);
            var tabs = new[] { "video.example", "news.example" }.Select(host => space.Tabs.Single(tab => Origin(tab)?.Host == host)).ToArray();
            (chosenTab, otherTab, site) = (tabs[0].Id, tabs[1].Id, Origin(tabs[0])!);

            // Before any choice, the page opens on the default engine and keeps its state when it closes.
            var before = Guid.NewGuid();
            app.Send(new OpenPage(before, workspace, spaceId, chosenTab, window));
            Assert.Equal(EngineKind.Chromium, CreatedOn(before, chromium, webKit));
            app.Report(chromiumEngine, new PageCreated(before));
            app.Send(new ReleasePage(before, KeepsState: true));
            app.Report(chromiumEngine, new PageClosed(before, new PageRestoreState(tabs[0].Url!, [1, 2, 3])));

            // The site's next page opens on the chosen engine, which never takes what another engine kept.
            app.Send(new ChooseSiteEngine(spaceId, site, EngineKind.WebKit));
            var chosen = Guid.NewGuid();
            app.Send(new OpenPage(chosen, workspace, spaceId, chosenTab, window));
            Assert.Equal(new CreatePage(chosen, space.ProfileId, IsPrivate: false, window, RestoreState: null),
                webKit.Commands.OfType<CreatePage>().Single());
            var other = Guid.NewGuid();
            app.Send(new OpenPage(other, workspace, spaceId, otherTab, window));
            Assert.Equal(EngineKind.Chromium, CreatedOn(other, chromium, webKit));

            // A private Space's choice holds there alone and stays in memory.
            var privateWorkspace = TestWorkspaces.Opened(app.Send(new OpenWorkspace(WorkspaceKind.Private, Seed: null)));
            var privateSpace = app.Workspace(privateWorkspace).Current.Spaces.Single().Id;
            var otherSite = Origin(tabs[1])!;
            app.Send(new ChooseSiteEngine(privateSpace, otherSite, EngineKind.WebKit));
            app.Send(new ReleasePage(other, KeepsState: false));
            var stillDefault = Guid.NewGuid();
            app.Send(new OpenPage(stillDefault, workspace, spaceId, otherTab, window));
            Assert.Equal(EngineKind.Chromium, CreatedOn(stillDefault, chromium, webKit));

            // An engine this device did not register, an origin that is not one and a locked Space are refused.
            using (var webKitOnly = new CrestApp()) {
                webKitOnly.RegisterEngine(new EngineRegistration(EngineKind.WebKit, EngineCapability.Required, IsDefault: true), _ => { });
                Assert.Equal(new UnregisteredEngine(EngineKind.Chromium), Assert.Throws<Rejected>(() =>
                    webKitOnly.Send(new ChooseSiteEngine(Guid.NewGuid(), site, EngineKind.Chromium))).Rejection);
            }
            var blank = new SiteOrigin("https", "", 443);
            Assert.Equal(new InvalidSiteOrigin(blank), Assert.Throws<Rejected>(() =>
                app.Send(new ChooseSiteEngine(spaceId, blank, EngineKind.WebKit))).Rejection);
            var guarded = app.Workspace(workspace).Current.Spaces.First(space => space.Settings.AccessPolicy != SpaceAccessPolicy.Open).Id;
            app.Send(new LockSpace(guarded));
            Assert.Equal(new SpaceLocked(guarded), Assert.Throws<Rejected>(() =>
                app.Send(new ChooseSiteEngine(guarded, site, EngineKind.WebKit))).Rejection);
        }

        // The persistent session's choice is kept, and the private Space's is not.
        var (relaunched, persistent, _) = DeviceApp(directory);
        using var relaunchedDisposal = relaunched;
        var (chromiumAgain, webKitAgain) = (new RecordingEngine(), new RecordingEngine());
        relaunched.RegisterEngine(new EngineRegistration(EngineKind.Chromium, EngineCapability.Required, IsDefault: true),
            chromiumAgain.Run);
        relaunched.RegisterEngine(new EngineRegistration(EngineKind.WebKit, EngineCapability.Required, IsDefault: false), webKitAgain.Run);
        var relaunchedWindow = Guid.NewGuid();
        relaunched.Send(new OpenWindow(relaunchedWindow, persistent, Saved: false, null, null, [], RestoresTabs: true));
        var (kept, unkept) = (Guid.NewGuid(), Guid.NewGuid());
        relaunched.Send(new OpenPage(kept, persistent, spaceId, chosenTab, relaunchedWindow));
        relaunched.Send(new OpenPage(unkept, persistent, spaceId, otherTab, relaunchedWindow));
        Assert.Equal(EngineKind.WebKit, CreatedOn(kept, chromiumAgain, webKitAgain));
        Assert.Equal(EngineKind.Chromium, CreatedOn(unkept, chromiumAgain, webKitAgain));
    }
}
