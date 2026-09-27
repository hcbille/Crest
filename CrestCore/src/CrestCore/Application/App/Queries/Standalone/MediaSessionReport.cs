using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// What the media-session store does with one page report, given what it
/// remembers of the reporting document, how many identities it remembers and
/// the next ordinal it would give. Refused with `InvalidMediaSessionCount` for
/// a negative count.
public sealed record MediaSessionReport(MediaSessionEvent Event, MediaSessionIdentity Identity, int RetainedIdentities,
    ulong NextOrdinal) : StandaloneQuery<MediaSessionEventDecision> {
    #region Actions - Answering

    internal override MediaSessionEventDecision Answer(StandaloneContext context) =>
        MediaSessionPolicy.Decide(Event, Identity, RetainedIdentities, NextOrdinal);

    #endregion
}
