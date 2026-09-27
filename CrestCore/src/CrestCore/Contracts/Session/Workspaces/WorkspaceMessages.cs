namespace CrestCore.Contracts;

#region Queries

/// The session `Seed` opens as, repaired as a stored session is when it loads
/// and resolved, for a view that shows Spaces no workspace holds: a preview,
/// or a draft before it is saved. Nothing opens, so no change of it is ever
/// published. It reads no state, so a host may ask it without an app.
public sealed record DetachedSession(SessionState Seed) : StandaloneQuery<SessionState>;

/// The session a first launch starts with when nothing is carried to it: one
/// Personal Space wearing the Winter house look, showing a Start Page, marked
/// as the disposable first-install seed. A file that holds no session takes it
/// from `AdoptLegacySession` without a seed; a launch without a file opens it
/// as the seed of an `OpenWorkspace`. It reads no state, so a host may ask it
/// without an app.
public sealed record FirstInstallSession() : StandaloneQuery<SessionState>;

#endregion

#region Rejections

/// A workspace of this kind opens only by borrowing a Space of the workspace
/// that owns it, with `BorrowSpace`.
public sealed record BorrowedWorkspaceRequiresSpace(WorkspaceKind Kind) : Rejection;

/// A session the core was asked to hold, such as a seed a workspace opens
/// from, is one no workspace can hold, for the reason `Flaw` names.
public sealed record InvalidSession(SessionFlaw Flaw) : Rejection;

/// The first rule a session breaks that keeps a workspace from holding it.
public enum SessionFlaw {
    /// It is not a session in the stored format.
    Unreadable,
    /// A Space, its profile, one of its tabs or a Space deletion has no identity.
    MissingIdentity,
    /// Two Spaces share an identity.
    DuplicateSpace,
    /// Two Spaces share a profile, which would share its website data across them.
    SharedProfile,
    /// Two tabs share an identity.
    DuplicateTab,
    /// A Space deletion names a Space, or a profile, the session does not hold,
    /// or names one Space twice.
    UnknownDeletion
}

/// The core keeps no session file, or its file holds no session yet, so a
/// workspace that keeps the file opens only once `AdoptLegacySession` has given
/// the file its first session, or from a seed. A `CloudSyncIntent` is refused
/// with it too while that session is not open.
public sealed record NoStoredSession : Rejection;

/// The Space no longer uses the profile the intent names.
public sealed record SpaceProfileChanged(Guid SpaceId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "That Space is no longer available.";

    #endregion
}

/// The session the core keeps in its file was opened and closed in this
/// launch. It takes no edits again until the next launch opens the file.
public sealed record StoredSessionClosed : Rejection;

#endregion
