namespace CrestCore.Contracts;

#region Intents - Pages

/// An intent about the pages this device hosts: which tab or transient request
/// owns each, and which engine hosts it. The platform names each page with an
/// identity it makes, which does not depend on the engine.
public abstract record PageIntent : Intent;

/// The person left the notice of a page's failed navigation for the page
/// behind it. Refused when the page is not open.
public sealed record LeavePageFailure(Guid PageId) : PageIntent;

/// Gives a page a new owner without recreating it: a tab in another
/// workspace or window, or a tab that adopts a transient request's page. The
/// engine page stays in its profile, so the destination Space must keep the
/// same one. Refused like `OpenPage`, and when the destination keeps another
/// profile.
public sealed record MovePage(Guid PageId, Guid WorkspaceId, Guid SpaceId, Guid? TabId, Guid WindowId) : PageIntent;

/// Asks a page to load what the person typed or chose: an address, or words
/// the Space's search engine looks up. The core resolves `Input` by the
/// address rules of the page's Space and engine, shows the page heading there
/// and asks the page's engine to load it. Refused when the page is not open or
/// its engine holds no page to load into, its Space is locked or being
/// deleted, or `Input` names nothing a page can load, as blank input does.
public sealed record Navigate(Guid PageId, string Input) : PageIntent;

/// Opens a page for a tab, or for a transient request when `TabId` is null, in
/// a Space of a workspace attached to this device, hosted by an open window.
/// `Transient` says how a page with no tab presents. The page opens on the
/// engine chosen for the site its tab shows (`ChooseSiteEngine`) when that
/// engine is registered, and otherwise on the default engine; that engine is
/// asked to create it. Refused when the workspace,
/// Space or window is not there, the Space is locked or being deleted, the
/// window already hosts a page for the tab, or no engine is the default.
public sealed record OpenPage(Guid PageId, Guid WorkspaceId, Guid SpaceId, Guid? TabId, Guid WindowId,
    TransientPresentation? Transient = null) : PageIntent;

/// Moves a page to `Engine`. The core closes the page on its engine, keeping
/// nothing, creates it on `Engine` in the same profile and window, and once
/// that engine has created it, loads the address the page showed. The page
/// keeps its identity, its owner and its window; its history, form state and
/// anything its old engine kept stay behind. A page already on `Engine`
/// stays. Refused when the page is not open, its Space is locked or being
/// deleted, or this device did not register `Engine`.
public sealed record RehostPage(Guid PageId, EngineKind Engine) : PageIntent;

/// Its owner is done with a page. The page is gone at once, and its engine is
/// asked to close what it still holds. `KeepsState` says the owner kept what it
/// needs to bring the page back.
public sealed record ReleasePage(Guid PageId, bool KeepsState) : PageIntent;

/// The system asks for memory back at `Level`. The core unloads pages nobody
/// sees, off screen longest first, as many as the device's platform gives
/// back at that level. A page a window shows, one playing, capturing or in
/// Picture in Picture, one whose tab keeps its page loaded, and a Quick
/// Window's or Peek's page all stay.
public sealed record ReportMemoryPressure(MemoryPressureLevel Level) : PageIntent;

#endregion

#region Intents - Staged Links

/// No page will load the link the engine of `SourcePageId` staged as
/// `StagedLinkId`, so its engine forgets it. A source page the core no longer
/// hosts took its staged links with it.
public sealed record DiscardStagedLink(Guid SourcePageId, Guid StagedLinkId) : PageIntent;

/// The first load of the page `PageId` names, when it loads `Url`, runs the
/// link the engine of `SourcePageId` staged as `StagedLinkId`. Refused with
/// `StagedLinkElsewhere` when the page is on another engine or profile than
/// the page the link was followed in, or has loaded something already.
public sealed record StageLink(Guid PageId, Guid SourcePageId, Guid StagedLinkId, string Url) : PageIntent;

#endregion

#region Queries

/// Whether returning a saved or pinned tab to the address it belongs to would
/// change anything: the tab is away from that page, or its page in `WindowId`
/// is heading to another. Not for a tab that belongs nowhere or is not there.
public sealed record CanReturnToSavedAddress(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId)
    : Query<SavedAddressReturn>;

/// Whether returning a tab to its saved address would take it or its page
/// somewhere else.
public sealed record SavedAddressReturn(bool ChangesPage);

/// What a page surface shows for a tab whose surface is `Surface`, or for no
/// tab: whether its engine holds a page for it, whether that page's navigation
/// or its process failed, and whether the surface restores an unloaded page by
/// itself. It reads no state, so a view may ask it without an app.
public sealed record PresentPage(TabSurface? Surface, bool HasPage, bool HasNavigationFailure, bool HasProcessFailure,
    bool RestoresUnloaded) : StandaloneQuery<PagePresented>;

/// What a page surface shows.
public sealed record PagePresented(PagePresentation Presentation);

#endregion

#region Changes

/// The core recorded a page's finished navigation to `Url` in a Space: the
/// tab that owns the page, when it has one, shows the address and the page's
/// title, and the Space's history holds a visit when the address is one
/// history keeps. A Quick Window or Peek page has no tab.
public sealed record NavigationRecorded(Guid PageId, Guid WorkspaceId, Guid SpaceId, Guid? TabId, string Url) : Change;

/// The core adopted a page its engine opened by itself as the page `PageId`
/// names, owned by the tab `TabId` it opened in `SpaceId` of the workspace
/// `WorkspaceId`. The window `WindowId` names hosts the page, and shows the
/// tab when `Shows`.
public sealed record OfferedPageAdopted(Guid PageId, Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, bool Shows)
    : Change;

/// A page moved to another owner, or its engine created, failed or closed it.
public sealed record PageChanged(PageState Page) : Change;

/// One page this device hosts: the workspace and Space it belongs to, the tab
/// that owns it, the engine that hosts it, where it stands there and its live
/// state. A page without a tab belongs to a transient request: a Quick Window,
/// a Peek, or one of its engine's own pages that Settings shows.
[Observed]
public sealed record PageState(Guid Id, Guid WorkspaceId, Guid SpaceId, Guid? TabId, EngineKind Engine, PagePhase Phase,
    PageLiveState Live);

/// A page opened, and its engine is creating it.
public sealed record PageOpened(PageState Page) : Change;

/// A page of a Space moved from engine `From` to engine `To`, for `Reason`,
/// with the address of the site `Origin`, or null for an address that is not
/// a web page's. The `PageChanged` before it carries the page on its new
/// engine.
public sealed record PageRehosted(Guid PageId, Guid SpaceId, SiteOrigin? Origin, EngineKind From, EngineKind To, RehostReason Reason)
    : Change;

/// Its owner released a page, which is gone.
public sealed record PageRemoved(Guid PageId) : Change;

/// The core unloaded a page to give memory back. The tab keeps its place, and
/// its next page restores what this one showed. The page is gone, as
/// `PageRemoved` also says.
public sealed record PageUnloaded(Guid PageId, Guid WorkspaceId, Guid TabId) : Change;

#endregion

#region Rejections - Pages

/// A page with this identity is already open.
public sealed record DuplicatePage(Guid PageId) : Rejection;

/// The page's engine holds no page to load into: it could not create it, or
/// the page closed.
public sealed record PageNotLoadable(Guid PageId) : Rejection;

/// The Space keeps another profile than the one the page's engine page lives
/// in, so the page cannot move there.
public sealed record PageProfileMismatch(Guid PageId, Guid SpaceId) : Rejection;

/// The page cannot load the link staged in `SourcePageId`: it lives on another
/// engine or profile, or its engine already holds its page.
public sealed record StagedLinkElsewhere(Guid PageId, Guid SourcePageId) : Rejection;

/// The tab already owns `PageId` in this window; a window hosts one page for a
/// tab at a time. Windows that share their pages reuse that one, and a window
/// with pages of its own, as each iPad scene has, opens its own.
public sealed record TabAlreadyHasPage(Guid TabId, Guid PageId) : Rejection;

/// The intent names a page that is not open.
public sealed record UnknownPage(Guid PageId) : Rejection;

#endregion

#region Rejections - Spaces

/// The Space is being deleted, so nothing new may live in its profile.
public sealed record SpaceBeingDeleted(Guid SpaceId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "That Space is being deleted.";

    #endregion
}

/// The workspace holds no Space with this identity.
public sealed record UnknownSpace(Guid SpaceId) : Rejection;

#endregion

#region Models

/// Why a page's navigation to `Url` failed. `Error` names the problem the same
/// way whichever engine saw it, and is what behavior that differs by failure
/// reads. `ReplacedDocument` says the failure took the place of the document
/// the page showed, as an engine's committed error page does; otherwise the
/// page still shows that document behind the failure, and leaving the failure
/// returns to it. `Domain` and `Code` are the engine's own error, which the
/// failure page shows as technical details and nothing branches on.
public sealed record PageFailure(NavigationError Error, string? Url, bool ReplacedDocument, string Domain, long Code);

/// What media a page runs now: audio or video playing, the camera or the
/// microphone capturing, or a video in Picture in Picture.
[Flags]
public enum PageMediaActivity {
    None = 0,
    Playing = 1 << 0,
    Capturing = 1 << 1,
    PictureInPicture = 1 << 2
}

#endregion
