using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// This device's link preferences, which the device store keeps and never
/// syncs, and where a link another app hands a window opens under them.
internal sealed partial class Device {
    #region Variables

    private LinkPreferences links = LinkPreferencePolicy.Default;

    #endregion

    #region Actions - Link intents

    /// Runs one link intent, publishing the preferences when they changed. An
    /// adoption always publishes them, so the platform reads them from launch.
    public void Handle(LinkIntent intent, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        lock (gate) {
            if (intent is AdoptLinkPreferences adoption) {
                Adopt(adoption);
                changes.Publish(new LinkPreferencesChanged(links));
                return;
            }
            Revise(intent switch {
                ChooseExternalLinkDestination choice =>
                    links with { Destination = choice.Destination, DestinationSpaceId = choice.SpaceId ?? links.DestinationSpaceId },
                SetLinkBehavior setting => setting.Behavior.Setting(links, setting.IsOn),
                ChoosePeekModifier choice => links with { PeekModifier = choice.Modifier },
                ChooseQuickWindowArchivePolicy choice => links with { ArchivePolicy = choice.Policy },
                AddLinkRoute adding => LinkPreferencePolicy.Adding(links, adding),
                EditLinkRoute edit => LinkPreferencePolicy.Editing(links, edit),
                MoveLinkRoute move => LinkPreferencePolicy.Moving(links, move),
                RemoveLinkRoute removal => LinkPreferencePolicy.Removing(links, removal),
                RememberQuickWindowSpace remembering => LinkPreferencePolicy.Remembering(links, remembering.Url, remembering.SpaceId),
                _ => throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "The device does not handle this intent.")
            }, changes);
        }
    }

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

    #endregion
}
