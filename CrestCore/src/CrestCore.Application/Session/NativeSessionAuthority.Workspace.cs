using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

internal sealed partial class NativeSessionAuthority {
    #region Actions - Imports

    public SessionEdit Handle(ImportSpaces intent, SessionTurn turn) =>
        Importing(turn.Basis, intent, intent.Spaces, turn.Previewed, turn.Now, turn.Ids, import => import.AddSpaces());

    /// Imports the review setup holds for this workspace; see
    /// `ImportReviewedSpaces`.
    public SessionEdit Handle(ImportReviewedSpaces intent, SessionTurn turn) {
        if (!workspaceKind.KeepsAppPreferences) throw new Rejected(new PersistentWorkspaceRequired(workspaceId));
        var review = device?.ImportReview(workspaceId) ?? throw new Rejected(new NoSetup());
        return Importing(turn.Basis, intent, [.. review.Spaces.Select(space => space.Source)], turn.Previewed, turn.Now, turn.Ids,
            import => import.ImportReviewed(review.Spaces, turn.Ids));
    }

    /// Applies the manual setup the device holds for this workspace; see
    /// `ApplyManualSetup`. The device ends the setup once the session accepts it.
    public SessionEdit Handle(ApplyManualSetup intent, SessionTurn turn) {
        if (!workspaceKind.KeepsAppPreferences) throw new Rejected(new PersistentWorkspaceRequired(workspaceId));
        var setup = device?.ManualSetup(workspaceId) ?? throw new Rejected(new NoManualSetup());
        return Importing(turn.Basis, intent, [.. setup.Spaces.Select(NativeWorkspaceImport.SetupSpace)], turn.Previewed, turn.Now, turn.Ids,
            import => import.ApplySetup(setup));
    }

    /// An import's work, which only the persistent workspace takes: `apply`
    /// runs the intent's own rules over the Spaces read from `spaces`, then
    /// every record takes the identity sync needs and the issuing window shows
    /// what the import brought. Unless the import is only `previewed`, no Space
    /// it changes may be locked; a locked Space it leaves as it was never
    /// refuses it.
    private SessionEdit Importing(SessionState basis, ImportWorkspace intent, IReadOnlyList<SpaceState> spaces, bool previewed,
        DateTimeOffset now, IIdSource ids, Action<NativeWorkspaceImport> apply) {
        if (!workspaceKind.KeepsAppPreferences) throw new Rejected(new PersistentWorkspaceRequired(workspaceId));
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var import = new NativeWorkspaceImport(basis, spaces);
        apply(import);
        if (!previewed && import.Changed.FirstOrDefault(IsLockedUnderGate) is { } locked) throw new Rejected(new SpaceLocked(locked.Id));
        var result = import.Finish(now, ids, followUp);
        return new(result.Session, SyncStaging.Import, followUp,
            new SessionTabEvents(result.Copied, Favicon: null, Imported: result.Imported));
    }

    /// The session `intent` would leave, at `now`, and where the tabs it would
    /// place came from; nothing changes. It shows Spaces this process has not
    /// unlocked, as a person sees them before they import, and otherwise
    /// throws the `Rejected` that would refuse the import. Its new identities
    /// are drawn only for the answer.
    internal ImportedWorkspace Preview(ImportWorkspace intent, DateTimeOffset now) {
        ArgumentNullException.ThrowIfNull(intent);
        lock (Gate) {
            var edit = Edit(intent, Stamp(now), new SystemIdSource(), pages: null, previewed: true)!;
            var events = edit.Events ?? SessionTabEvents.None;
            return new(edit.Next, events.Imported ?? [], [.. events.Copies.Select(copy => copy.Copied(workspaceId))]);
        }
    }

    /// The session an export writes, as accepted now. Throws `Rejected` with
    /// `SpaceLocked` while this process holds no grant to show one of its
    /// Spaces, whose tabs and history the file would carry.
    internal SessionState Exported() {
        lock (Gate) {
            if (session.Spaces.FirstOrDefault(IsLockedUnderGate) is { } locked) throw new Rejected(new SpaceLocked(locked.Id));
            return session;
        }
    }

    #endregion
}
