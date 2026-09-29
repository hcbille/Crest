using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// What the device store holds: every saved window's record, the saved
/// windows the next launch reopens, back to front, the persistent session's
/// site permission choices in storage order and its site engine choices least
/// recent first, the person's shortcut choices and link preferences, the
/// unfinished manual setup it keeps for the next launch, whether this device
/// has completed setup, and what it has adopted from an installed release.
internal sealed record DeviceRecords(IReadOnlyList<SavedWindow> Windows, IReadOnlyList<Guid> Reopening,
    IReadOnlyList<SitePermissionRecord> SitePermissions, IReadOnlyList<SiteEngineChoice> SiteEngines, ShortcutOverrides Shortcuts,
    LinkPreferences Links, KeptSetupDraft? SetupDraft, bool SetupCompleted, IReadOnlySet<DeviceAdoption> Adopted,
    EngineKind? DefaultEngine = null) {
    #region Static Variables

    public static readonly DeviceRecords Empty = new([], [], [], [], ShortcutOverrides.None, LinkPreferencePolicy.Default,
        SetupDraft: null, SetupCompleted: false, new HashSet<DeviceAdoption>());

    #endregion

    #region Actions - Adoption

    /// These records, having adopted `adoption` too.
    public DeviceRecords Adopting(DeviceAdoption adoption) => this with { Adopted = new HashSet<DeviceAdoption>(Adopted) { adoption } };

    #endregion

    #region Actions - Equality

    public bool Equals(DeviceRecords? other) => other is not null
        && Windows.SequenceEqual(other.Windows)
        && Reopening.SequenceEqual(other.Reopening)
        && SitePermissions.SequenceEqual(other.SitePermissions)
        && SiteEngines.SequenceEqual(other.SiteEngines)
        && DefaultEngine == other.DefaultEngine
        && Shortcuts.SameAs(other.Shortcuts)
        && Links.Equals(other.Links)
        && KeptSetupDraft.Same(SetupDraft, other.SetupDraft)
        && SetupCompleted == other.SetupCompleted
        && Adopted.SetEquals(other.Adopted);

    public override int GetHashCode() => HashCode.Combine(Windows.Count, SitePermissions.Count, Adopted.Count);

    #endregion
}
