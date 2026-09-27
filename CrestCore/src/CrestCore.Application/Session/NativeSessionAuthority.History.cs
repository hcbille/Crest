using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

internal sealed partial class NativeSessionAuthority {
    #region Types

    /// When the session was last swept, and the retention each Space had then.
    internal sealed record SweepMark(DateTimeOffset At, IReadOnlyList<SpaceRetention> Retention) {
        #region Actions - Throttling

        /// Whether a sweep at `now` of `session` would repeat this one: it comes
        /// less than `MinimumSweepSpacing` later, and no Space's retention
        /// changed. A clock that went backwards never holds a sweep back.
        public bool Covers(DateTimeOffset now, SessionState session) =>
            now >= At && now - At < MinimumSweepSpacing && Retention.SequenceEqual(SpaceRetention.Of(session));

        #endregion
    }

    /// What a Space keeps and for how long.
    internal sealed record SpaceRetention(Guid SpaceId, CurrentTabCleanup Cleanup, DataRetentionPreferences Records) {
        #region Actions - Reading

        public static IReadOnlyList<SpaceRetention> Of(SessionState session) => [.. session.Spaces.Select(space =>
            new SpaceRetention(space.Id, space.Settings.BrowsingPreferences.CurrentTabCleanup, space.Settings.BrowsingPreferences.DataRetention))];

        #endregion
    }

    #endregion

    #region Variables

    /// The shortest gap between two sweeps of one session. Windows becoming
    /// active together, or an activation landing on a periodic sweep, sweep once.
    private static readonly TimeSpan MinimumSweepSpacing = TimeSpan.FromMinutes(1);

    /// The last sweep this session ran; null until it runs one.
    private SweepMark? lastSweep;

    #endregion

    #region Actions - History

    public SessionEdit Handle(ClearHistory intent, SessionTurn turn) {
        IEnumerable<SpaceState> spaces = intent.SpaceId is { } spaceId ? [Editable(turn.Basis, spaceId)] : EditableSpaces(turn.Basis);
        return new(Replacing(turn.Basis, [.. spaces.Select(space => space.History.Count == 0 ? space : space with { History = [] })]),
            SyncStaging.Deletion);
    }

    public SessionEdit Handle(RemoveHistoryAddress intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var address = new WebAddress(intent.Address).Normalized;
        return new(Replacing(turn.Basis, WithoutHistory(space, entry => address is not null && entry.Url == address)), SyncStaging.Deletion);
    }

    public SessionEdit Handle(RemoveHistoryRange intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        if (intent.End < intent.Start) throw new Rejected(new InvalidDateRange());
        var removed = RecordRemovalPolicy.WithinRange(Seconds(space.History.Select(entry => entry.LastVisitedAt)),
            StoredSessionCodec.Seconds(intent.Start), StoredSessionCodec.Seconds(intent.End)).ToHashSet();
        return new(Replacing(turn.Basis, WithoutHistory(space, (_, index) => removed.Contains(index))), SyncStaging.Deletion);
    }

    private static SpaceState WithoutHistory(SpaceState space, Func<HistoryEntryState, bool> removes) =>
        WithoutHistory(space, (entry, _) => removes(entry));

    private static SpaceState WithoutHistory(SpaceState space, Func<HistoryEntryState, int, bool> removes) {
        var kept = space.History.Where((entry, index) => !removes(entry, index)).ToArray();
        return kept.Length == space.History.Count ? space : space with { History = kept };
    }

    #endregion

    #region Actions - Retention

    /// Cleans up and applies retention in every Space not being deleted, or
    /// nothing when the last sweep covers this one.
    public SessionEdit? Handle(SweepExpiredRecords intent, SessionTurn turn) {
        if (lastSweep?.Covers(turn.Now, turn.Basis) == true) return null;
        var kept = device?.ShownTabs(workspaceId);
        var swept = EditableSpaces(turn.Basis, maintains: true).Select(space => Expired(CleanedUp(space, turn.Now, kept), turn.Now)).ToArray();
        return new(Replacing(turn.Basis, swept), SyncStaging.Expiry, Sweep: new(turn.Now, SpaceRetention.Of(turn.Basis)));
    }

    public SessionEdit Handle(CleanUpCurrentTabs intent, SessionTurn turn) {
        IEnumerable<SpaceState> spaces = intent.SpaceId is { } spaceId
            ? [Editable(turn.Basis, spaceId, maintains: true)] : EditableSpaces(turn.Basis, maintains: true);
        var kept = device?.ShownTabs(workspaceId);
        return new(Replacing(turn.Basis, [.. spaces.Select(space => CleanedUp(space, turn.Now, kept))]), SyncStaging.Expiry);
    }

    /// `space` with its open tabs unused for longer than its cleanup lifetime
    /// archived, keeping `kept`: the tabs windows show and saved windows will.
    private static SpaceState CleanedUp(SpaceState space, DateTimeOffset now, IReadOnlySet<Guid>? kept) {
        if (space.Settings.BrowsingPreferences.CurrentTabCleanup.Lifetime is not { } lifetime) return space;
        var edited = BrowserTabCollection.Restore(space);
        edited.CleanupCurrentTabs(null, lifetime, now, kept?.ToArray());
        return space.Tabs.SequenceEqual(edited.TabStates) ? space : edited.Capture(space);
    }

    /// `space` without the history and archive entries older than it keeps them.
    private static SpaceState Expired(SpaceState space, DateTimeOffset now) {
        var retention = space.Settings.BrowsingPreferences.DataRetention;
        var seconds = StoredSessionCodec.Seconds(now);
        if (retention.History.Lifetime is { } history) {
            var expired = RecordRemovalPolicy.Expired(Seconds(space.History.Select(entry => entry.LastVisitedAt)), seconds,
                history.TotalSeconds).ToHashSet();
            space = WithoutHistory(space, (_, index) => expired.Contains(index));
        }
        if (retention.Archive.Lifetime is { } archive) {
            var expired = RecordRemovalPolicy.Expired(Seconds(space.ArchivedTabs.Select(archived => archived.ArchivedAt)), seconds,
                archive.TotalSeconds).ToHashSet();
            if (expired.Count > 0) space = space with { ArchivedTabs = [.. space.ArchivedTabs.Where((_, index) => !expired.Contains(index))] };
        }
        return space;
    }

    #endregion

    #region Actions - Archive

    /// Reopens the tab the Space archived last, which the issuing window shows.
    public SessionEdit Handle(ReopenClosedTab intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var newest = space.ArchivedTabs.MaxBy(archived => archived.ArchivedAt) ?? throw new Rejected(new NoArchivedTabs(space.Id));
        return Handle(new RestoreArchivedTab(intent.WorkspaceId, intent.WindowId, space.Id, newest.Tab.Id), turn);
    }

    /// Reopens the archived tab as an open tab, which the issuing window shows.
    public SessionEdit Handle(RestoreArchivedTab intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var index = space.ArchivedTabs.ToList().FindIndex(archived => archived.Tab.Id == intent.TabId);
        if (index < 0) throw new Rejected(new UnknownArchivedTab(intent.TabId));
        if (turn.Basis.Spaces.Any(candidate => candidate.Tabs.Any(tab => tab.Id == intent.TabId)))
            throw new Rejected(new TabAlreadyExists(intent.TabId));
        var remaining = space with { ArchivedTabs = [.. space.ArchivedTabs.Where((_, position) => position != index)] };
        var edited = BrowserTabCollection.Restore(remaining);
        var restored = edited.RestoreArchived(space.ArchivedTabs[index].Tab, turn.Now);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId)).ShowTab(space.Id, restored.Id);
        return new(Replacing(turn.Basis, edited.Capture(remaining)), SyncStaging.Creation, followUp);
    }

    #endregion

    #region Actions - Dates

    /// The dates as the stored format's seconds, which the removal policies read.
    private static double[] Seconds(IEnumerable<DateTimeOffset> dates) => dates.Select(StoredSessionCodec.Seconds).ToArray();

    #endregion
}
