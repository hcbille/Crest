namespace CrestCore.Contracts;

#region Intents

/// An intent about which workspaces this device's windows may show: opening
/// one, borrowing a Space into one and closing one. The core gives each
/// workspace its identity and publishes `WorkspaceOpened` with its whole
/// session, which every later change to that session names.
public abstract record WorkspaceIntent : Intent;

/// Opens a borrowed workspace that shows the Space `SpaceId` of the workspace
/// `WorkspaceId` with tabs, folders, history and archive of its own, and
/// publishes `WorkspaceOpened` for it. The borrowed Space keeps its owner's
/// profile, settings and access grants, and follows its owner: each edit of
/// the owner's Space settings reaches it in the same answer, and it closes
/// once its owner no longer lends that Space with that profile. It keeps
/// nothing: it is never saved or synced.
///
/// Refused with `UnknownWorkspace`, `UnknownSpace`, `SpaceBeingDeleted`,
/// `SpaceLocked`, `BorrowedProfileRequiresOwner` when `WorkspaceId` borrows its
/// own Space, and `SpaceProfileChanged` when the Space no longer uses the
/// profile `ProfileId` names.
public sealed record BorrowSpace(Guid WorkspaceId, Guid SpaceId, Guid ProfileId) : WorkspaceIntent;

/// Closes a workspace and every workspace that borrows a Space from it, the
/// borrowers first. For each, the core publishes `PageRemoved` for its pages,
/// asking their engines to close what they still hold, then `WindowClosed` for
/// each window over it, then `WorkspaceClosed`. Its session takes no edits
/// afterwards. The device keeps the saved records of its windows, so a later
/// launch restores them: closing a workspace is not closing its windows one by
/// one. A workspace that is not open publishes nothing.
public sealed record CloseWorkspace(Guid WorkspaceId) : WorkspaceIntent;

/// Opens a workspace of `Kind` that this device's windows may show, and
/// publishes `WorkspaceOpened` with the identity the core gave it and its
/// whole session.
///
/// Without a seed, a kind that keeps a file opens the session the core keeps
/// in its file, as it loaded and repaired it: that session is saved on every
/// edit and syncs through the journal kept beside it. A tab the repair gave a
/// new identity follows as `TabCopied` from the tab whose image it wears. The
/// file's session opens once per launch; opening it again while it is open
/// publishes its `WorkspaceOpened` again. Any other kind starts from the Space
/// template of its kind, such as the one Space a private workspace starts with.
///
/// `Seed` is a session a platform builds for a launch without a file (an
/// isolated run, a preview or a test): its fields alone, as a platform sends
/// any record the core resolves values of. It opens repaired as the file's
/// session does, with `TabCopied` for each tab the repair gave a new
/// identity. A seeded workspace keeps nothing: it is never saved or synced.
///
/// Refused with `BorrowedWorkspaceRequiresSpace` for a kind that opens only by
/// borrowing, `NoStoredSession` when the core keeps no file or its file holds
/// no session yet (`AdoptLegacySession` gives it its first), `StoredSessionClosed`
/// once the file's session was closed, and `InvalidSession` for a seed the core
/// cannot hold.
[MessageLimit(64 * 1024 * 1024)]
public sealed record OpenWorkspace(WorkspaceKind Kind, SessionState? Seed) : WorkspaceIntent;

#endregion

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
