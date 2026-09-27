using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Removes the history entries of a Space last visited from `Start` up to,
/// but not including, `End`. A range that ends before it starts is refused
/// with `InvalidDateRange`.
public sealed record RemoveHistoryRange(Guid WorkspaceId, Guid SpaceId, DateTimeOffset Start, DateTimeOffset End)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        var space = workspace.Editable(turn.Basis, SpaceId);
        if (End < Start) throw new Rejected(new InvalidDateRange());
        var removed = RecordRemovalPolicy.WithinRange(workspace.Seconds(space.History.Select(entry => entry.LastVisitedAt)),
            StoredSessionCodec.Seconds(Start), StoredSessionCodec.Seconds(End)).ToHashSet();
        return new(NativeSessionAuthority.Replacing(turn.Basis, workspace.WithoutHistory(space, (_, index) => removed.Contains(index))),
            SyncStaging.Deletion);
    }

    #endregion
}
