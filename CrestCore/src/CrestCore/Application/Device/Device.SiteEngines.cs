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

    /// Opens `origin`'s new pages on `engine` from now on, as a choice made in
    /// `spaceId`: for every Space when the device store keeps its choices, or
    /// for that Space alone. Throws `Rejected` for an origin that is not valid
    /// or a locked Space.
    public void Choose(Guid spaceId, SiteOrigin origin, EngineKind engine) {
        ArgumentNullException.ThrowIfNull(origin);
        ArgumentNullException.ThrowIfNull(engine);
        if (!origin.IsValid) throw new Rejected(new InvalidSiteOrigin(origin));
        var (keeps, locked) = ChoiceScope(spaceId);
        if (locked) throw new Rejected(new SpaceLocked(spaceId));
        lock (gate) {
            if (keeps) {
                if (keptEngines.Choose(new(null, origin, engine))) storage?.EnqueueDevice(Records());
            } else {
                passingEngines.Choose(new(spaceId, origin, engine));
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
