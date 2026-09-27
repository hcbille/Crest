using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// The display order of the published sessions and the one that owns the
/// system's Now Playing. Refused with `MediaSessionLimitReached` past
/// `MaximumSessions` and `DuplicateMediaSession` for a repeated identity.
public sealed record MediaSessionOrder(IReadOnlyList<MediaSessionEntry> Sessions) : StandaloneQuery<MediaSessionArbitration> {
    #region Static Variables

    public const int MaximumSessions = 64;

    #endregion

    #region Actions - Answering

    internal override MediaSessionArbitration Answer(StandaloneContext context) => MediaSessionPolicy.Arbitrate(Sessions);

    #endregion
}
