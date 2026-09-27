using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The access area: which Spaces this process may show. It keeps the one
/// grant authority the device attaches to every session it shows, so a
/// borrowed workspace and the one it borrows from unlock and lock together.
/// Each intent publishes the access of every Space profile it changed.
internal sealed class SpaceAccess(Device device, SpaceAccessAuthority authority) : ISpaceAccessIntentHandler<ChangeFeed> {
    #region Actions - Intents

    public void Handle(SpaceAccessIntent intent, ChangeFeed changes) => intent.Dispatch(this, changes);

    public void Handle(BeginUnlockingSpace begin, ChangeFeed changes) {
        // The Space is read before the grants are locked, so the session's gate
        // is never taken inside the authority's.
        var unlocking = device.Workspace(begin.WorkspaceId).Unlockable(begin.SpaceId);
        lock (authority) Publish(authority.Begin(unlocking.Assignment, unlocking.RequiresAuthentication, begin.RequestId), changes);
    }

    public void Handle(FinishUnlockingSpace finish, ChangeFeed changes) {
        lock (authority) Publish(authority.Finish(finish.SpaceId, finish.RequestId, finish.Authenticated), changes);
    }

    public void Handle(LockSpace locking, ChangeFeed changes) {
        lock (authority) Publish(authority.Lock(locking.SpaceId), changes);
    }

    public void Handle(LockAllSpaces locking, ChangeFeed changes) {
        lock (authority) Publish(authority.LockAll(locking.SceneWentInactive), changes);
    }

    /// Publishes the access of each Space profile `changed` names. The caller
    /// holds the authority's lock.
    private void Publish(IReadOnlyList<SpaceAccessAssignment> changed, ChangeFeed changes) {
        foreach (var assignment in changed)
            changes.Publish(new SpaceLockChanged(assignment.Space, assignment.Profile, authority.IsUnlocked(assignment),
                authority.IsAuthenticating(assignment)));
    }

    #endregion
}
