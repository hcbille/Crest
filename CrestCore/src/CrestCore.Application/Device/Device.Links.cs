using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// This device's link preferences, which the device store keeps and never
/// syncs, and where a link another app hands a window opens under them.
internal sealed partial class Device : ILinkIntentHandler<ChangeFeed> {
    #region Variables

    private LinkPreferences links = LinkPreferencePolicy.Default;

    #endregion

    #region Actions - Link intents

    /// Runs one link intent holding the device lock, publishing the
    /// preferences when they changed.
    public void Handle(LinkIntent intent, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        lock (gate) intent.Dispatch(this, changes);
    }

    /// An adoption always publishes the preferences, so the platform reads
    /// them from launch. The caller holds the device lock, as for each link
    /// intent.
    public void Handle(AdoptLinkPreferences adoption, ChangeFeed changes) {
        Adopt(adoption);
        changes.Publish(new LinkPreferencesChanged(links));
    }

    public void Handle(ChooseExternalLinkDestination choice, ChangeFeed changes) =>
        Revise(links with { Destination = choice.Destination, DestinationSpaceId = choice.SpaceId ?? links.DestinationSpaceId }, changes);

    public void Handle(SetLinkBehavior setting, ChangeFeed changes) => Revise(setting.Behavior.Setting(links, setting.IsOn), changes);

    public void Handle(ChoosePeekModifier choice, ChangeFeed changes) => Revise(links with { PeekModifier = choice.Modifier }, changes);

    public void Handle(ChooseQuickWindowArchivePolicy choice, ChangeFeed changes) => Revise(links with { ArchivePolicy = choice.Policy }, changes);

    public void Handle(AddLinkRoute adding, ChangeFeed changes) => Revise(LinkPreferencePolicy.Adding(links, adding), changes);

    public void Handle(EditLinkRoute edit, ChangeFeed changes) => Revise(LinkPreferencePolicy.Editing(links, edit), changes);

    public void Handle(MoveLinkRoute move, ChangeFeed changes) => Revise(LinkPreferencePolicy.Moving(links, move), changes);

    public void Handle(RemoveLinkRoute removal, ChangeFeed changes) => Revise(LinkPreferencePolicy.Removing(links, removal), changes);

    public void Handle(RememberQuickWindowSpace remembering, ChangeFeed changes) =>
        Revise(LinkPreferencePolicy.Remembering(links, remembering.Url, remembering.SpaceId), changes);

    /// Forgets a deleted Space in the link preferences: its routes, its
    /// choice as the external-link Space and the sites that remembered it.
    public void ForgetLinks(Guid spaceId, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(changes);
        lock (gate) Revise(LinkPreferencePolicy.Forgetting(links, spaceId), changes);
    }

    /// Keeps `revised` and publishes it when it differs from the preferences
    /// the device holds. The caller holds the device lock.
    private void Revise(LinkPreferences revised, ChangeFeed changes) {
        if (revised.Equals(links)) return;
        links = revised;
        storage?.EnqueueDevice(Records());
        changes.Publish(new LinkPreferencesChanged(links));
    }

    /// Carries the preferences an installed release kept into the device store
    /// once, in place of the defaults. The preferences and the adoption's
    /// marker are saved together, so a launch that could not save them adopts
    /// them again. The caller holds the device lock.
    private void Adopt(AdoptLinkPreferences intent) {
        if (storage is not { } target || adopted.Contains(DeviceAdoption.LinkPreferences)) return;
        links = LegacyLinkPreferencesDocument.Read(intent.Preferences) ?? links;
        adopted.Add(DeviceAdoption.LinkPreferences);
        target.EnqueueDevice(Records());
    }

    #endregion

    #region Actions - Routing

    /// Where a link another app hands a window opens, under this device's
    /// preferences and the Spaces of the window's workspace: none being
    /// deleted, and never a locked one.
    public ExternalLinkPlacement Answer(RouteExternalLink question) {
        ArgumentNullException.ThrowIfNull(question);
        var window = Opened(question.WindowId);
        var authority = Workspace(window.WorkspaceId);
        var spaces = authority.Current.Spaces;
        Guid shown;
        LinkPreferences preferences;
        lock (gate) {
            shown = window.ShownSpaceId;
            preferences = links;
        }
        var context = new LinkRoutingContext([.. spaces.Select(space => space.Id)], shown,
            [.. spaces.Where(space => authority.IsDeleting(space.Id)).Select(space => space.Id)]);
        var locked = spaces.Where(authority.IsLocked).Select(space => space.Id).ToHashSet();
        return LinkRoutingPolicy.DecideExternal(question.Url, preferences, context, locked) is { } placed
            ? new(placed.SpaceId, placed.OpensQuickWindow, placed.SubstitutesForLockedSpace)
            : new(null, false, false);
    }

    /// What following a link from a page does: a page for a tab reads the
    /// tab's place and saved address, a Peek brings the tabs it opens to the
    /// front, and the rest follows this device's link preferences.
    public LinkNavigationAnswer Answer(LinkNavigation question, Pages pages) {
        ArgumentNullException.ThrowIfNull(question);
        ArgumentNullException.ThrowIfNull(pages);
        LinkPreferences preferences;
        lock (gate) preferences = links;
        var gesture = question.Gesture;
        var (peek, newTab) = preferences.PeekModifier.Intent(gesture.Modifiers, gesture.MiddleClick);
        var page = pages.Hosted(question.PageId);
        var tab = page is { TabId: { } tabId }
            ? Attached(page.WorkspaceId)?.Current.Spaces.FirstOrDefault(space => space.Id == page.SpaceId)?.Tabs
                .FirstOrDefault(candidate => candidate.Id == tabId)
            : null;
        bool focuses = preferences.FocusesNewTabs || page is { TabId: null, Transient.OpensNewTabsInFront: true };
        return new(LinkNavigationPolicy.Decide(question.Url, gesture.UserActivated, gesture.TopLevel, peek, newTab,
            gesture.Modifiers.HasFlag(ShortcutModifiers.Shift), focuses, hasContext: tab is not null, tab?.Placement,
            tab?.SavedAddress, preferences.OpensPeekAutomatically));
    }

    /// Whether a window a page opened comes to the front, as the gesture and
    /// this device's link preferences decide.
    public OpenedWindowSelected Answer(OpenedWindowSelection question) {
        ArgumentNullException.ThrowIfNull(question);
        LinkPreferences preferences;
        lock (gate) preferences = links;
        var gesture = question.Gesture;
        var (_, newTab) = preferences.PeekModifier.Intent(gesture.Modifiers, gesture.MiddleClick);
        return new(LinkNavigationPolicy.SelectsOpenedWindow(newTab, gesture.Modifiers.HasFlag(ShortcutModifiers.Shift),
            preferences.FocusesNewTabs));
    }

    #endregion
}
