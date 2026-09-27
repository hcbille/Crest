using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Removes a Space whose deletion `OperationId` began, once the platform has
/// erased its profile's data, and saves that before it returns. The Space
/// that takes its place becomes the launch Space when it was one, and the
/// window that asked moves there when it showed the removed one.
public sealed record FinishDeletingSpace(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid OperationId)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    /// Removes the Space and its deletion. The Space that takes its place is
    /// where its window goes and, when it was the launch Space, the new one.
    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        workspace.RequireOwnedSpaces();
        var (space, pending) = workspace.Deleting(turn.Basis, SpaceId);
        if (pending is null || pending.Id != OperationId) throw new Rejected(new WrongDeletionOperation(space.Id));
        SpaceOrganizationPolicy.RequireRemovable(turn.Basis.Spaces.Count);
        var index = turn.Basis.Spaces.ToList().IndexOf(space);
        var spaces = turn.Basis.Spaces.Where(candidate => candidate.Id != space.Id).ToArray();
        var neighbor = spaces[Math.Min(index, spaces.Length - 1)].Id;
        var followUp = new WindowFollowUp(workspace.IssuingWindow(WindowId));
        if (followUp.Window?.ShownSpaceId == space.Id) followUp.ShowSpace(neighbor);
        return new(turn.Basis with {
            Spaces = spaces,
            SpaceDeletions = [.. turn.Basis.SpaceDeletions.Where(deletion => deletion != pending)],
            DefaultSpaceId = turn.Basis.DefaultSpaceId == space.Id ? neighbor : turn.Basis.DefaultSpaceId
        }, SyncStaging.Removal, followUp);
    }

    #endregion
}
