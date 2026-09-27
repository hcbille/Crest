namespace CrestCore.Contracts;

#region Intents

/// Brings Spaces into the persistent workspace: a file's Spaces
/// (`ImportSpaces`), imported Spaces a person reviewed
/// (`ImportReviewedSpaces`) or the Spaces of the manual setup the device holds
/// (`ApplyManualSetup`). The choices about them are typed and name each Space
/// by its identity. An import is saved with its sync journal before it
/// returns.
///
/// Folder and history records keep their identities unless another Space
/// already holds them, because those identities are global in sync. A Space,
/// profile or tab that collides with another takes a new identity: each
/// imported tab is published in `TabsImported` with the tab it came from, and
/// each of the workspace's own tabs that took a new identity as `TabCopied`.
/// The window `WindowId` shows the first Space the import brought or changed.
///
/// Refused with `PersistentWorkspaceRequired` for any other workspace,
/// `SpaceLocked` when it would change a locked Space, giving it tabs or
/// folders or another name or look, `InvalidImport` for Spaces or choices it
/// cannot read, `SpaceLimitReached` when the workspace would hold too many
/// Spaces, and `SpaceBeingDeleted` when a Space it names is going away. A
/// locked Space the import leaves as it was, such as one a review leaves out,
/// a draft left unchanged or one it only moves in the order, never refuses it.
public abstract record ImportWorkspace(Guid WorkspaceId, Guid WindowId) : SessionIntent(WorkspaceId);

/// Applies the manual setup this device holds for the workspace: each new
/// Space of the setup joins with its identity, profile, name and look, and
/// each existing Space takes the name and look the setup gave it. When the
/// setup's order was edited, the Spaces take it, followed by any Space the
/// setup does not name. A first launch's Spaces stop being disposable. The
/// setup ends once it is applied.
///
/// Refused with `NoManualSetup` when no setup is in progress for the
/// workspace, `SpaceProfileChanged` when an existing Space no longer uses the
/// setup's profile, and `SpaceAlreadyExists` or `ProfileInUse` when a new
/// Space takes an identity or profile another Space holds.
public sealed record ApplyManualSetup(Guid WorkspaceId, Guid WindowId) : ImportWorkspace(WorkspaceId, WindowId);

/// Imports the review setup holds for the workspace, as its choices say. An
/// included Space becomes a new Space or joins the existing one it names,
/// taking the name and look the review gives it, with the tabs the review
/// includes in the placements it chose and the saved folders those tabs need;
/// a folder matches one the destination holds by title. Pinned tabs past a
/// destination's limit become saved tabs in an `Imported Pinned Tabs` folder.
/// A new Space keeps its archive and history. Over a first launch's
/// disposable Spaces, the reviewed Spaces replace them.
///
/// Refused with `NoSetup` when setup holds no review for the workspace, and
/// `NoIncludedSpaces` when the review includes none.
public sealed record ImportReviewedSpaces(Guid WorkspaceId, Guid WindowId) : ImportWorkspace(WorkspaceId, WindowId);

/// Adds each Space of `Spaces` after the workspace's own, whole: its tabs,
/// folders, splits, archive and history, as `ReadArchive` or `ReadImport`
/// brought them. Pinned tabs past the limit become saved tabs. The window
/// shows the first of them, on its first tab.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ImportSpaces(Guid WorkspaceId, Guid WindowId, IReadOnlyList<SpaceState> Spaces)
    : ImportWorkspace(WorkspaceId, WindowId);

#endregion

#region Queries

/// The session the import would leave its workspace with, without importing
/// anything: what a person sees before they import. It shows Spaces this
/// process has not unlocked, since an import that changes one waits until it
/// is; otherwise it is refused as the import would be.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ImportPreview(ImportWorkspace Import) : Query<ImportedWorkspace>;

/// The session an import would leave: `Session`, the tabs it would place from
/// its Spaces, and the workspace's own tabs that would take a new identity.
public sealed record ImportedWorkspace(SessionState Session, IReadOnlyList<ImportedTab> Imported, IReadOnlyList<TabCopied> Copied);

#endregion

#region Rejections

/// The import's Spaces or choices cannot be read, for the reason `Flaw` names.
public sealed record InvalidImport(ImportFlaw Flaw) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest couldn’t read the Spaces to import.";

    #endregion
}

/// Why the core cannot read an import.
public enum ImportFlaw {
    /// Its Spaces are not Spaces in the stored format.
    Unreadable,
    /// A Space holds a split whose tabs are not one run of open tabs, which
    /// repair would rewrite.
    MalformedSplit,
    /// A choice names a Space the import does not bring, a Space it brings has
    /// no choice, or two of its Spaces share an identity, so a choice cannot
    /// tell them apart.
    UnpairedChoices
}

/// A reviewed import includes none of its Spaces.
public sealed record NoIncludedSpaces : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Choose at least one Space to import.";

    #endregion
}

/// Another Space already uses the profile `ProfileId`, and a profile belongs
/// to one Space.
public sealed record ProfileInUse(Guid ProfileId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Another Space already uses this Space’s browsing data.";

    #endregion
}

#endregion

#region Models

/// A tab an import placed, `TabId`, and the tab it came from: `SourceTabId`,
/// open or archived, of the import's Space at position `Source` among its
/// Spaces.
public sealed record ImportedTab(Guid TabId, int Source, Guid SourceTabId);

/// A reviewed tab that moves to `Placement`.
public sealed record TabPlacementChoice(Guid TabId, TabPlacement Placement);

#endregion
