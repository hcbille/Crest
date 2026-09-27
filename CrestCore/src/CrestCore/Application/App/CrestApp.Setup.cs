using CrestCore.Contracts;

namespace CrestCore.Application;

public sealed partial class CrestApp {
    #region Actions - Setup

    /// Finishes the setup open on this device; see `FinishSetup`. The manual
    /// setup is applied through the workspace as any import is, after the
    /// Space the guide would open in is found unlocked; then the device
    /// completes setup. The caller holds the lock.
    private void Finish(FinishSetup intent, ChangeFeed changes) {
        var finish = device.FinishingSetup();
        var authority = device.Workspace(finish.WorkspaceId);
        var apply = new ApplyManualSetup(finish.WorkspaceId, intent.WindowId);
        if (finish.OpensGuide) {
            var proposed = finish.AppliesManualSetup ? authority.Preview(apply, clock.Now).Session : authority.Current;
            if (proposed.Spaces.FirstOrDefault() is { } first && authority.IsLocked(first)) throw new Rejected(new GuideSpaceLocked(first.Id));
        }
        if (finish.AppliesManualSetup) {
            authority.Handle(apply, clock.Now, ids, pages);
            device.FinishManualSetup(finish.WorkspaceId, changes);
        }
        device.FinishedSetup(finish, finish.OpensGuide ? authority.Current.Spaces.FirstOrDefault()?.Id : null, changes);
    }

    #endregion
}
