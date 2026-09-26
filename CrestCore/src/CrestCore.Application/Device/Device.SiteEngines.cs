using CrestCore.Contracts;

namespace CrestCore.Application;

/// Which engine each site's new pages open on. The device store keeps the
/// choices made in the persistent session's Spaces, which hold for every
/// Space; a choice made in any other Space (private, seeded, or one no
/// attached session holds) holds for that Space alone and lives in memory
/// until the process ends. Such a Space still follows the kept choices.
internal sealed partial class Device {
    #region Variables

    /// The persistent session's choices, which the device store keeps.
    private readonly SiteEngineLedger keptEngines = new();
    /// Every other Space's choices, which live as long as the process.
    private readonly SiteEngineLedger passingEngines = new();

    #endregion

    #region Actions - Site engine intents

    /// Records the choice. The caller has checked that its engine is
    /// registered.
    public void Choose(ChooseSiteEngine intent) {
        ArgumentNullException.ThrowIfNull(intent);
        if (!intent.Origin.IsValid) throw new Rejected(new InvalidSiteOrigin(intent.Origin));
        var (keeps, locked) = ChoiceScope(intent.SpaceId);
        if (locked) throw new Rejected(new SpaceLocked(intent.SpaceId));
        lock (gate) {
            if (keeps) {
                if (keptEngines.Choose(new(null, intent.Origin, intent.Engine))) storage?.EnqueueDevice(Records());
            } else {
                passingEngines.Choose(new(intent.SpaceId, intent.Origin, intent.Engine));
            }
        }
    }

    #endregion

    #region Actions - Site engine queries

    /// The engine chosen for new pages of `origin` in `spaceId`, or null when
    /// none is. Called without the device lock, since it reads the sessions.
    public EngineKind? ChosenEngine(Guid spaceId, SiteOrigin origin) {
        ArgumentNullException.ThrowIfNull(origin);
        var (keeps, _) = ChoiceScope(spaceId);
        lock (gate) return (keeps ? null : passingEngines.Chosen(spaceId, origin)) ?? keptEngines.Chosen(null, origin);
    }

    #endregion
}
