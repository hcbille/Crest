using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

internal sealed partial class NativeSessionAuthority {
    #region Actions - Spaces

    private static SpaceDeletionState? PendingDeletion(SessionState value, Guid spaceId) =>
        value.SpaceDeletions.FirstOrDefault(deletion => deletion.SpaceId == spaceId);

    /// `space` with `settings`, keeping the settings it had when nothing
    /// changed, so an edit that changes nothing publishes nothing.
    private static SpaceState Configured(SpaceState space, SpaceSettings settings) =>
        settings == space.Settings ? space : space with { Settings = settings };

    /// Refuses a Space intent a borrowed workspace cannot apply: the
    /// workspace it borrows from owns the Space's profile and its settings,
    /// and makes, orders and deletes Spaces.
    private void RequireOwnedSpaces() {
        if (!workspaceKind.OwnsSpaces) throw new Rejected(new BorrowedProfileRequiresOwner(workspaceId));
    }

    /// `basis` with the Space an intent edited in its place.
    private SessionEdit SettingSpace(SessionState basis, SpaceState space, Func<SpaceSettings, SpaceSettings> edit, SyncStaging staging) =>
        new(Replacing(basis, Configured(space, edit(space.Settings))), staging);

    public SessionEdit Handle(CreateSpace intent, SessionTurn turn) {
        RequireOwnedSpaces();
        if (turn.Basis.Spaces.Any(space => space.Id == intent.SpaceId)) throw new Rejected(new SpaceAlreadyExists(intent.SpaceId));
        if (turn.Basis.Spaces.Count >= BrowserLimits.Spaces) throw new Rejected(new SpaceLimitReached(BrowserLimits.Spaces));
        var space = SpaceTemplate.For(workspaceKind.IsPrivate)
            .Make(intent.SpaceId, turn.Ids.Next(), turn.Ids.Next, turn.Basis.Spaces.Count + 1, turn.Now);
        // A new Space is the one its window shows next, on its only tab.
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId)).ShowSpace(space.Id).ShowTab(space.Id, space.Tabs[0].Id);
        return new(turn.Basis with { Spaces = [.. turn.Basis.Spaces, space] }, SyncStaging.Creation, followUp);
    }

    public SessionEdit Handle(SetSpaceIdentity intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var space = Editable(turn.Basis, intent.SpaceId);
        var name = SpaceOrganizationPolicy.ChosenName(intent.Name);
        return SettingSpace(turn.Basis, space, settings => settings with {
            Name = name,
            Symbol = SpaceOrganizationPolicy.Symbol(intent.Symbol),
            Accent = intent.Accent
        }, SyncStaging.Edit);
    }

    public SessionEdit Handle(SetSpaceBranding intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var branding = SpaceBrandingPolicy.Normalize(intent.Branding);
        return SettingSpace(turn.Basis, Editable(turn.Basis, intent.SpaceId), settings => settings with { Branding = branding }, SyncStaging.Edit);
    }

    public SessionEdit Handle(SetCredentialPreferences intent, SessionTurn turn) {
        RequireOwnedSpaces();
        return SettingSpace(turn.Basis, Editable(turn.Basis, intent.SpaceId), settings => settings with { CredentialPreferences = intent.Preferences },
            SyncStaging.Protection);
    }

    /// Asking for authentication is always allowed, even for a locked Space;
    /// letting a Space open freely is the decision authentication guards.
    public SessionEdit Handle(SetSpaceAccess intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var space = Editable(turn.Basis, intent.SpaceId, maintains: intent.Policy != SpaceAccessPolicy.Open);
        return SettingSpace(turn.Basis, space, settings => settings with { AccessPolicy = intent.Policy }, SyncStaging.Protection);
    }

    public SessionEdit Handle(SetDefaultSpace intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var space = Editable(turn.Basis, intent.SpaceId);
        return new(turn.Basis.DefaultSpaceId == space.Id ? turn.Basis : turn.Basis with { DefaultSpaceId = space.Id }, SyncStaging.Edit);
    }

    public SessionEdit Handle(ReorderSpaces intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var byId = turn.Basis.Spaces.ToDictionary(space => space.Id);
        if (intent.SpaceIds.Count != byId.Count || intent.SpaceIds.Distinct().Count() != byId.Count || intent.SpaceIds.Any(id => !byId.ContainsKey(id)))
            throw new Rejected(new InvalidSpaceOrder());
        return new(turn.Basis.Spaces.Select(space => space.Id).SequenceEqual(intent.SpaceIds)
            ? turn.Basis : turn.Basis with { Spaces = [.. intent.SpaceIds.Select(id => byId[id])] }, SyncStaging.Edit);
    }

    public SessionEdit Handle(ExpandSavedTabs intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var space = Editable(turn.Basis, intent.SpaceId);
        return space.Settings.IsSavedTabsExpanded == intent.IsExpanded ? new(turn.Basis, SyncStaging.Edit)
            : SettingSpace(turn.Basis, space, settings => settings with { IsSavedTabsExpanded = intent.IsExpanded, SavedTabsExpansionModifiedAt = turn.Now },
                SyncStaging.Edit);
    }

    #endregion

    #region Actions - Space deletion

    /// The Space a deletion names, locked or not, and its deletion under way.
    private static (SpaceState Space, SpaceDeletionState? Pending) Deleting(SessionState basis, Guid spaceId) =>
        (basis.Spaces.FirstOrDefault(space => space.Id == spaceId) ?? throw new Rejected(new UnknownSpace(spaceId)),
            PendingDeletion(basis, spaceId));

    /// Records the deletion, which leaves the Space as it is until it is
    /// removed. The window showing a Space that is going away moves to the
    /// first one that stays.
    public SessionEdit Handle(BeginDeletingSpace intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var (space, pending) = Deleting(turn.Basis, intent.SpaceId);
        if (pending is not null)
            return pending.Id == intent.OperationId ? new(turn.Basis, SyncStaging.Withdrawal) : throw new Rejected(new WrongDeletionOperation(space.Id));
        SpaceOrganizationPolicy.RequireRemovable(turn.Basis.Spaces.Count - turn.Basis.SpaceDeletions.Count);
        var next = turn.Basis with { SpaceDeletions = [.. turn.Basis.SpaceDeletions, new(intent.OperationId, space.Id, space.ProfileId)] };
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        if (followUp.Window?.ShownSpaceId == space.Id)
            followUp.ShowSpace(next.Spaces.First(candidate => PendingDeletion(next, candidate.Id) is null).Id);
        return new(next, SyncStaging.Withdrawal, followUp);
    }

    /// Removes the Space and its deletion. The Space that takes its place is
    /// where its window goes and, when it was the launch Space, the new one.
    public SessionEdit Handle(FinishDeletingSpace intent, SessionTurn turn) {
        RequireOwnedSpaces();
        var (space, pending) = Deleting(turn.Basis, intent.SpaceId);
        if (pending is null || pending.Id != intent.OperationId) throw new Rejected(new WrongDeletionOperation(space.Id));
        SpaceOrganizationPolicy.RequireRemovable(turn.Basis.Spaces.Count);
        var index = turn.Basis.Spaces.ToList().IndexOf(space);
        var spaces = turn.Basis.Spaces.Where(candidate => candidate.Id != space.Id).ToArray();
        var neighbor = spaces[Math.Min(index, spaces.Length - 1)].Id;
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        if (followUp.Window?.ShownSpaceId == space.Id) followUp.ShowSpace(neighbor);
        return new(turn.Basis with {
            Spaces = spaces,
            SpaceDeletions = [.. turn.Basis.SpaceDeletions.Where(deletion => deletion != pending)],
            DefaultSpaceId = turn.Basis.DefaultSpaceId == space.Id ? neighbor : turn.Basis.DefaultSpaceId
        }, SyncStaging.Removal, followUp);
    }

    /// A private workspace starts over with one fresh private Space, which
    /// the window that asked shows. Nothing it held ever synced.
    public SessionEdit Handle(ResetPrivateBrowsing intent, SessionTurn turn) {
        if (!workspaceKind.IsPrivate) throw new Rejected(new NotPrivateWorkspace(workspaceId));
        var space = SpaceTemplate.Private.Make(turn.Ids.Next(), turn.Ids.Next(), turn.Ids.Next, number: 1, turn.Now);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId)).ShowSpace(space.Id).ShowTab(space.Id, space.Tabs[0].Id);
        return new(turn.Basis with { Spaces = [space], SpaceDeletions = [], DefaultSpaceId = null }, Staging: null, followUp);
    }

    #endregion
}
