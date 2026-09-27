using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Erases what the engines keep for a profile: all of it, or one site's. Every
/// registered engine is asked, whether or not it has started or shows any
/// page, since a profile's store outlives the run that filled it. A deletion
/// ends with `DataDeleted` once each engine asked has answered, deleted only
/// when every one of them erased everything. A profile whose data this run
/// erased may finish its Space's deletion; a relaunch erases it again before
/// that deletion finishes. Nothing here is saved.
internal sealed class DataDeletions(Engines engines, IIdSource ids) {
    #region Static Variables

    /// The longest host a site can have.
    private const int MaximumHostLength = 253;

    #endregion

    #region Types

    /// One deletion, until every engine asked has answered.
    private sealed class Deletion(Guid requestId, Guid? profileId) {
        public Guid RequestId { get; } = requestId;
        /// The profile whose data this erases in full, if it does.
        public Guid? ProfileId { get; } = profileId;
        /// The erasures still out, each with the engine it went to.
        public Dictionary<Guid, Engine> Waiting { get; } = [];
        public bool Erased { get; set; } = true;
    }

    #endregion

    #region Variables

    private readonly Dictionary<Guid, Deletion> byErasure = [];
    /// The profiles whose data this run erased in full.
    private readonly HashSet<Guid> erasedProfiles = [];

    #endregion

    #region Actions - Intents

    public void Handle(DataDeletionIntent intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        switch (intent) {
            case DeleteProfileData deleting:
                // Until every engine erases it again, the profile's data is not known gone.
                erasedProfiles.Remove(deleting.ProfileId);
                Start(new(deleting.RequestId, deleting.ProfileId),
                    erasure => new EraseProfileData(deleting.ProfileId, deleting.Ephemeral, erasure), changes, issue);
                break;
            case DeleteSiteData deleting:
                if (deleting.Host.Trim() is not { Length: > 0 and <= MaximumHostLength } host) throw new Rejected(new InvalidSiteHost());
                Start(new(deleting.RequestId, profileId: null),
                    erasure => new EraseSiteData(deleting.ProfileId, deleting.Ephemeral, host.ToLowerInvariant(), erasure), changes,
                    issue);
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "Data deletions do not handle this intent.");
        }
    }

    /// Asks every registered engine for its part of `deletion`.
    private void Start(Deletion deletion, Func<Guid, EngineCommand> erasing, ChangeFeed changes,
        Action<Engine, EngineCommand> issue) {
        foreach (var engine in engines.All) {
            var erasure = ids.Next();
            deletion.Waiting[erasure] = engine;
            byErasure[erasure] = deletion;
            issue(engine, erasing(erasure));
        }
        if (deletion.Waiting.Count == 0) Finish(deletion, changes);
    }

    #endregion

    #region Actions - Reports

    /// One engine answered its part of a deletion; an answer from another
    /// engine, or to an erasure nobody waits on, changes nothing.
    public void Report(Engine engine, EngineEvent report, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(changes);
        if (report is not DataErased erased || !byErasure.TryGetValue(erased.ErasureId, out var deletion)
            || !ReferenceEquals(deletion.Waiting[erased.ErasureId], engine))
            return;
        byErasure.Remove(erased.ErasureId);
        deletion.Waiting.Remove(erased.ErasureId);
        deletion.Erased &= erased.Erased;
        if (deletion.Waiting.Count == 0) Finish(deletion, changes);
    }

    private void Finish(Deletion deletion, ChangeFeed changes) {
        if (deletion is { ProfileId: { } profile, Erased: true }) erasedProfiles.Add(profile);
        changes.Publish(new DataDeleted(deletion.RequestId, deletion.Erased));
    }

    #endregion

    #region Actions - Queries

    /// Whether this run erased profile `profileId`'s data on every engine.
    public bool Erased(Guid profileId) => erasedProfiles.Contains(profileId);

    #endregion
}
