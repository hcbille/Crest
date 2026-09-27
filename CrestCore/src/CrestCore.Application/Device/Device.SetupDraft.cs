using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

#region Types

/// What one setup intent needs: where it publishes the setup it leaves, and
/// where the identities of the Spaces it adds come from.
internal sealed record SetupDraftTurn(ChangeFeed Changes, IIdSource Ids);

#endregion

/// The manual setup this device holds: the one in progress over a workspace,
/// which follows that workspace's Spaces, and on a platform that keeps an
/// unfinished setup, the copy the device store keeps for the next launch.
/// `ApplyManualSetup` reads the one in progress and ends it once applied.
internal sealed partial class Device : ISetupDraftIntentHandler<SetupDraftTurn> {
    #region Variables

    /// The setup in progress, or null.
    private SetupDraft? setupDraft;
    /// What the device store keeps of an unfinished setup, which setup goes
    /// on with at its manual-setup step. Always null on a platform that keeps none.
    private KeptSetupDraft? keptSetupDraft;

    #endregion

    #region Actions - Setup intents

    /// Runs one setup intent holding the device lock, publishing the setup it
    /// leaves.
    public void Handle(SetupDraftIntent intent, SetupDraftTurn turn) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(turn);
        lock (gate) intent.Dispatch(this, turn);
    }

    public void Handle(AddSetupSpace adding, SetupDraftTurn turn) => KeepSetup(ManualSetupPolicy.Adding(HeldSetup(), turn.Ids.Next), turn.Changes);

    public void Handle(RemoveSetupSpace removal, SetupDraftTurn turn) =>
        KeepSetup(ManualSetupPolicy.Removing(HeldSetup(), removal.SpaceId), turn.Changes);

    public void Handle(MoveSetupSpace move, SetupDraftTurn turn) =>
        KeepSetup(ManualSetupPolicy.Moving(HeldSetup(), move.SpaceId, move.TargetSpaceId), turn.Changes);

    public void Handle(CustomizeSetupSpace customizing, SetupDraftTurn turn) =>
        KeepSetup(ManualSetupPolicy.Customizing(HeldSetup(), customizing.SpaceId, customizing.Customization), turn.Changes);

    /// The manual setup the device holds. Throws `Rejected` with
    /// `NoManualSetup` while it holds none. The caller holds the device lock.
    private SetupDraft HeldSetup() => setupDraft ?? throw new Rejected(new NoManualSetup());

    /// Starts a setup of `session`'s Spaces over `workspaceId`, or goes on with
    /// the one held or kept unless `startsOver`, and publishes it. The caller
    /// holds the device lock.
    private void BeginSetup(Guid workspaceId, SessionState session, bool startsOver, ChangeFeed changes, IIdSource ids) {
        var resumed = startsOver ? null
            : setupDraft is { } held && held.WorkspaceId == workspaceId ? held
            : keptSetupDraft?.For(workspaceId);
        var draft = resumed is null ? ManualSetupPolicy.Started(workspaceId, session, ids.Next) : ManualSetupPolicy.Reconciled(resumed, session);
        KeepSetup(draft, changes: null);
        changes.Publish(new SetupDraftChanged(draft));
    }

    /// Carries the setup an installed release kept into the device store
    /// once. The caller holds the device lock, as for each setup intent.
    public void Handle(AdoptSetupDraft intent, SetupDraftTurn turn) {
        if (storage is not { } target || adopted.Contains(DeviceAdoption.SetupDraft)) return;
        if (platform.KeepsSetupDraft) keptSetupDraft ??= LegacySetupDraftDocument.Read(intent.Draft);
        adopted.Add(DeviceAdoption.SetupDraft);
        target.EnqueueDevice(Records());
    }

    #endregion

    #region Actions - Applying

    /// The setup in progress over `workspaceId`, which `ApplyManualSetup`
    /// applies, or null when there is none.
    public SetupDraft? ManualSetup(Guid workspaceId) {
        lock (gate) return setupDraft is { } draft && draft.WorkspaceId == workspaceId ? draft : null;
    }

    /// The setup over `workspaceId` was applied: it ends.
    public void FinishManualSetup(Guid workspaceId, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(changes);
        lock (gate) {
            if (setupDraft?.WorkspaceId == workspaceId) KeepSetup(null, changes);
        }
    }

    /// The setup in progress over `workspaceId` following its Spaces as
    /// `next` holds them, answering the change to publish when it changed.
    /// The caller holds the device lock.
    private SetupDraftChanged? FollowingSpaces(Guid workspaceId, SessionState next) {
        if (setupDraft is not { } draft || draft.WorkspaceId != workspaceId) return null;
        var followed = ManualSetupPolicy.Reconciled(draft, next);
        if (ReferenceEquals(followed, draft)) return null;
        KeepSetup(followed, changes: null);
        return new(followed);
    }

    #endregion

    #region Actions - Keeping

    /// Holds `draft` as the setup in progress, and keeps it for the next
    /// launch on a platform that keeps one, publishing it into `changes` when
    /// it changed. The caller holds the device lock.
    private void KeepSetup(SetupDraft? draft, ChangeFeed? changes) {
        bool changed = !ReferenceEquals(draft, setupDraft);
        setupDraft = draft;
        var kept = platform.KeepsSetupDraft && draft is not null ? KeptSetupDraft.From(draft) : null;
        if (!KeptSetupDraft.Same(kept, keptSetupDraft)) {
            keptSetupDraft = kept;
            storage?.EnqueueDevice(Records());
        }
        if (changed) changes?.Publish(new SetupDraftChanged(draft));
    }

    #endregion
}
