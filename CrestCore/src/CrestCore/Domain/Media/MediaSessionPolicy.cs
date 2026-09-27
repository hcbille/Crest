using CrestCore.Contracts;

namespace CrestCore.Domain;

/// Arbitration between page media sessions, identical for every engine.
///
/// Each document reports sequenced events. Stale and retired reports are
/// dropped; a report can retire its document, withdraw its card, or publish it,
/// and a published document supersedes every other document of its tab. Only
/// media a person can control is published: a session offering play or pause,
/// the transport a player has. A notification chime or other short sound a
/// script plays offers neither, so it never takes a card or the system's Now
/// Playing. A muted session already shown keeps its card, since an engine may
/// withdraw a muted page's controls and the card is where it is unmuted. The
/// store remembers a bounded window of identities. Published sessions are
/// shown in first-published order, and one of them owns the system's Now
/// Playing: playing before paused, audible before silent, then the most
/// recently published.
public static class MediaSessionPolicy {
    #region Variables

    public const int MaximumRetainedIdentities = 512;

    #endregion

    #region Actions - Events

    public static MediaSessionEventDecision Decide(MediaSessionEvent report, MediaSessionIdentity identity,
        int retainedIdentities, ulong nextOrdinal) {
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(identity);
        if (retainedIdentities < 0) throw new Rejected(new InvalidMediaSessionCount(retainedIdentities));
        if (identity.IsRetired || report.Sequence <= (identity.LastSequence ?? 0))
            return new(false, 0, MediaSessionDisposition.Clear, false, null, nextOrdinal, false);
        int retained = retainedIdentities + (identity.LastSequence is null ? 1 : 0);
        int evict = Math.Max(0, retained - MaximumRetainedIdentities);
        if (report.IsInvalidated) return new(true, evict, MediaSessionDisposition.Retire, false, null, nextOrdinal, false);
        if (!report.HasActiveSession || !IsControllable(report, identity))
            return new(true, evict, MediaSessionDisposition.Clear, false, null, nextOrdinal, false);
        ulong ordinal = identity.Ordinal ?? nextOrdinal;
        ulong next = identity.Ordinal is null ? unchecked(nextOrdinal + 1) : nextOrdinal;
        // A card the person hid stays hidden until playback starts afresh.
        bool clearsDismissal = identity.IsDismissed && identity.PreviousPlayback != MediaPlaybackState.Playing
            && report.Playback == MediaPlaybackState.Playing;
        return new(true, evict, MediaSessionDisposition.Publish, true, ordinal, next, clearsDismissal);
    }

    // `PreviousPlayback` is known only while the document's card is shown.
    private static bool IsControllable(MediaSessionEvent report, MediaSessionIdentity identity) =>
        report.Actions.Contains(MediaSessionAction.Play) || report.Actions.Contains(MediaSessionAction.Pause)
        || (report.IsMuted && identity.PreviousPlayback is not null);

    #endregion

    #region Actions - Arbitration

    public static MediaSessionArbitration Arbitrate(IReadOnlyList<MediaSessionEntry> sessions) {
        ArgumentNullException.ThrowIfNull(sessions);
        if (sessions.Count > MediaSessionOrder.MaximumSessions)
            throw new Rejected(new MediaSessionLimitReached(MediaSessionOrder.MaximumSessions));
        if (sessions.GroupBy(session => session.Id, StringComparer.Ordinal).FirstOrDefault(group => group.Count() > 1) is { } repeated)
            throw new Rejected(new DuplicateMediaSession(repeated.Key));
        var order = Enumerable.Range(0, sessions.Count).ToList();
        order.Sort((lhs, rhs) => Compare(sessions[lhs], sessions[rhs]));
        int? owner = null;
        for (int index = 0; index < sessions.Count; index++) {
            if (sessions[index].Playback == MediaPlaybackState.None) continue;
            if (owner is not { } current || OwnsBefore(sessions[index], sessions[current])) owner = index;
        }
        return new(order, owner);
    }

    private static int Compare(MediaSessionEntry lhs, MediaSessionEntry rhs) =>
        lhs.Ordinal != rhs.Ordinal ? lhs.Ordinal.CompareTo(rhs.Ordinal) : string.CompareOrdinal(lhs.Id, rhs.Id);

    private static bool OwnsBefore(MediaSessionEntry candidate, MediaSessionEntry current) {
        if (candidate.Playback != current.Playback) return candidate.Playback > current.Playback;
        if (candidate.IsAudible != current.IsAudible) return candidate.IsAudible;
        return Compare(candidate, current) > 0;
    }

    #endregion
}
