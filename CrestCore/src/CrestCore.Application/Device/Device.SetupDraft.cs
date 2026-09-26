using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The manual setup this device holds: the one in progress over a workspace,
/// which follows that workspace's Spaces, and on a platform that keeps an
/// unfinished setup, the copy the device store keeps for the next launch.
/// `ApplyManualSetup` reads the one in progress and ends it once applied.
internal sealed partial class Device {
    #region Variables

    /// The setup in progress, or null.
    private SetupDraft? setupDraft;
    /// What the device store keeps of an unfinished setup, which the next
    /// `BeginManualSetup` goes on with. Always null on a platform that keeps none.
    private KeptSetupDraft? keptSetupDraft;

    #endregion

    #region Actions - Setup intents

    /// Runs one setup intent, publishing the setup it leaves.
    public void Handle(SetupDraftIntent intent, ChangeFeed changes, IIdSource ids) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(ids);
        if (intent is BeginManualSetup begin) {
            Begin(begin, changes, ids);
            return;
        }
        lock (gate) {
            switch (intent) {
                case AdoptSetupDraft adoption:
                    Adopt(adoption);
                    return;
                case DiscardManualSetup:
                    KeepSetup(null, changes);
                    return;
            }
            var draft = setupDraft ?? throw new Rejected(new NoManualSetup());
            KeepSetup(intent switch {
                AddSetupSpace => ManualSetupPolicy.Adding(draft, ids.Next),
                RemoveSetupSpace removal => ManualSetupPolicy.Removing(draft, removal.SpaceId),
                MoveSetupSpace move => ManualSetupPolicy.Moving(draft, move.SpaceId, move.TargetSpaceId),
                CustomizeSetupSpace customizing => ManualSetupPolicy.Customizing(draft, customizing.SpaceId, customizing.Customization),
                _ => throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "The device does not handle this intent.")
            }, changes);
        }
    }

    /// Starts or goes on with a setup of the workspace's Spaces, and always
    /// publishes it. The session is read outside the device lock.
    private void Begin(BeginManualSetup intent, ChangeFeed changes, IIdSource ids) {
        var authority = Workspace(intent.WorkspaceId);
        if (!authority.Kind.KeepsAppPreferences) throw new Rejected(new PersistentWorkspaceRequired(intent.WorkspaceId));
        var session = authority.Current;
        lock (gate) {
            var resumed = intent.StartsOver ? null
                : setupDraft is { } held && held.WorkspaceId == intent.WorkspaceId ? held
                : keptSetupDraft?.For(intent.WorkspaceId);
            var draft = resumed is null ? ManualSetupPolicy.Started(intent.WorkspaceId, session, ids.Next)
                : ManualSetupPolicy.Reconciled(resumed, session);
            KeepSetup(draft, changes: null);
            changes.Publish(new SetupDraftChanged(draft));
        }
    }

    /// Carries the setup an installed release kept into the device store
    /// once. The caller holds the device lock.
    private void Adopt(AdoptSetupDraft intent) {
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
