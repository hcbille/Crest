namespace CrestCore.Contracts;

#region Intents - Spaces

/// Starts deleting a Space as the deletion `OperationId` names, and saves
/// that before it returns. The Space and its profile stay exactly as they are
/// until `FinishDeletingSpace` removes them, which the platform sends once it
/// has erased the profile's data. Beginning again with the same operation, as
/// a relaunch does, changes nothing. The window that asked moves to the first
/// Space that stays, when it showed this one. A locked Space may be deleted.
public sealed record BeginDeletingSpace(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid OperationId)
    : SessionIntent(WorkspaceId);

/// Adds a Space after the others, with a profile of its own and one Start
/// Page tab. The core names it and gives it its symbol, accent and look; a
/// private workspace's Space never offers to save passwords. The window that
/// asked shows it, when that window is open over the workspace.
public sealed record CreateSpace(Guid WorkspaceId, Guid WindowId, Guid SpaceId) : SessionIntent(WorkspaceId);

/// Expands or collapses a Space's saved tabs, stamping when that changed so
/// the newest choice wins across devices.
public sealed record ExpandSavedTabs(Guid WorkspaceId, Guid SpaceId, bool IsExpanded) : SessionIntent(WorkspaceId);

/// Removes a Space whose deletion `OperationId` began, once the platform has
/// erased its profile's data, and saves that before it returns. The Space
/// that takes its place becomes the launch Space when it was one, and the
/// window that asked moves there when it showed the removed one.
public sealed record FinishDeletingSpace(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid OperationId)
    : SessionIntent(WorkspaceId);

/// Puts the workspace's Spaces in the order `SpaceIds` lists, which names
/// each of them once.
public sealed record ReorderSpaces(Guid WorkspaceId, IReadOnlyList<Guid> SpaceIds) : SessionIntent(WorkspaceId);

/// Replaces everything a private workspace holds with one fresh private
/// Space, which the window that asked shows.
public sealed record ResetPrivateBrowsing(Guid WorkspaceId, Guid WindowId) : SessionIntent(WorkspaceId);

/// Makes a Space the one a launch opens.
public sealed record SetDefaultSpace(Guid WorkspaceId, Guid SpaceId) : SessionIntent(WorkspaceId);

/// Sets whether a Space opens freely or asks the device owner first. Asking
/// for authentication is always allowed; letting a locked Space open freely
/// takes the grant that unlocking it gives.
public sealed record SetSpaceAccess(Guid WorkspaceId, Guid SpaceId, SpaceAccessPolicy Policy) : SessionIntent(WorkspaceId);

/// Sets how a Space's sidebar and icon look, within the ranges every device
/// draws.
public sealed record SetSpaceBranding(Guid WorkspaceId, Guid SpaceId, SpaceBranding Branding) : SessionIntent(WorkspaceId);

/// Renames a Space and sets its symbol and accent. A blank name reads as
/// "Untitled Space", and a blank symbol as the default one.
public sealed record SetSpaceIdentity(Guid WorkspaceId, Guid SpaceId, string Name, string Symbol, SpaceAccent Accent)
    : SessionIntent(WorkspaceId);

#endregion

#region Intents - Preferences

/// Sets whether a Space suggests searches as the person types, when it cleans
/// up open tabs, how it blocks content and how long it keeps what it browses.
/// A Space whose cleanup or retention changed is swept under the new rules in
/// the same edit. Its search engines have intents of their own.
public sealed record SetBrowsingPreferences(Guid WorkspaceId, Guid SpaceId, bool SearchSuggestionsEnabled,
    CurrentTabCleanup CurrentTabCleanup, ContentBlockingPolicy ContentBlocking, DataRetentionPreferences DataRetention)
    : SessionIntent(WorkspaceId);

/// Sets whether a Space offers to save and fill passwords, and where it keeps them.
public sealed record SetCredentialPreferences(Guid WorkspaceId, Guid SpaceId, CredentialPreferences Preferences)
    : SessionIntent(WorkspaceId);

#endregion

#region Rejections

/// The workspace borrows its one Space from the workspace that owns the
/// Space's profile, which changes the Space's settings and makes, orders and
/// deletes Spaces.
public sealed record BorrowedProfileRequiresOwner(Guid WorkspaceId) : Rejection;

/// Deleting the Space would leave the workspace without one.
public sealed record CannotDeleteLastSpace() : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest needs at least one Space.";

    #endregion
}

/// The order does not name each of the workspace's Spaces exactly once.
public sealed record InvalidSpaceOrder() : Rejection;

/// Only a private workspace starts over.
public sealed record NotPrivateWorkspace(Guid WorkspaceId) : Rejection;

/// The workspace already holds a Space with this identity.
public sealed record SpaceAlreadyExists(Guid SpaceId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "That Space already exists.";

    #endregion
}

/// The workspace already holds `Limit` Spaces, or would hold more.
public sealed record SpaceLimitReached(int Limit) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized(Argument = nameof(Limit))]
    public string Message => "Crest supports up to %lld Spaces.";

    #endregion
}

/// The Space's deletion is not the one the intent names: another operation
/// began it, or none did.
public sealed record WrongDeletionOperation(Guid SpaceId) : Rejection;

#endregion
