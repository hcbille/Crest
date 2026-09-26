using CrestCore.Contracts;

using Xunit;

namespace CrestCore.Tests;

/// Where another browser's saved passwords go: the Space each belongs with,
/// counted for the review, and the destination each goes to once the review
/// is imported, skipping Spaces that are gone or locked.
public sealed partial class BrowserContractsTests {
    [Fact]
    public void ImportedPasswordsGoWhereTheirSpacesGoExceptToGoneOrLockedSpaces() {
        var session = GuardedSession(withOpenSecondSpace: true);
        // Spaces the person made, which an import may join.
        session.AsObject().Remove("disposableSeedMarker");
        using var device = new TestDevice(session);
        var window = device.Showing(session);
        var (locked, open) = (device.Authority.Current.Spaces[0], device.Authority.Current.Spaces[1]);
        var work = ImportedSpace("Work", ImportedTab("https://mail.example/"));
        var home = ImportedSpace("Home", ImportedTab("https://bank.example/"));
        var reading = ImportedSpace("Reading", ImportedTab("https://news.example/"));
        ImportPasswordSource[] passwords = [new("Work", "site.example"), new("Home", "other.example"), new("Reading", "news.example"),
            new("Elsewhere", "BANK.example"), new("Elsewhere", "unknown.example")];
        device.Send(new StartSetup(device.Workspace, SetupEntry.ImportBrowser));
        device.Send(new OfferImportSources([ImportSource.Chrome]));
        device.Send(new ToggleImportSource(ImportSource.Chrome));
        device.Send(new ContinueImport());

        // Chrome's Spaces are its profiles: a password goes to its profile's
        // Space, else to the Space holding its site, else to the first Space.
        var review = Flowing(device.Send(new ReviewImport(ImportSource.Chrome, ReadSpaces(work, home, reading), passwords))).Review!;
        Assert.Equal([2, 2, 1], review.Spaces.Select(space => space.PasswordCount));
        Assert.Equal(locked.Id, review.Spaces[2].DestinationId);
        device.Send(new ChooseImportDestination(SpaceId(home), open.Id));

        ImportPasswordRoutes Routes() => device.Query(new ImportPasswordDestinations(device.Workspace, passwords));
        // Work comes in new, and is not in the workspace until the review is imported.
        Assert.Equal([[], [open.Id], [], [open.Id], []], Routes().Routes.Select(route => route.SpaceIds));
        TestGrants.Unlock(device.Send, device.Workspace, locked.Id);
        Assert.Equal([locked.Id], Routes().Routes[2].SpaceIds);
        var deleting = Guid.NewGuid();
        device.Send(new BeginDeletingSpace(device.Workspace, window, open.Id, deleting));
        device.Send(new DeleteProfileData(Guid.NewGuid(), open.ProfileId, Ephemeral: false));
        device.Send(new FinishDeletingSpace(device.Workspace, window, open.Id, deleting));
        Assert.Equal([[], [], [locked.Id], [], []], Routes().Routes.Select(route => route.SpaceIds));

        Assert.IsType<NoSetup>(Assert.Throws<Rejected>(() =>
            device.Query(new ImportPasswordDestinations(device.Attach(session, WorkspaceKind.Private), passwords))).Rejection);
    }
}
