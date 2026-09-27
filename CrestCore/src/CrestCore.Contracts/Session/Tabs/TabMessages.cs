namespace CrestCore.Contracts;

#region Intents

/// Chooses how a tab's icon is filled: from its page as the page changes, with
/// the page's favicon pulled once and kept, or with `Emoji`. A pulled favicon
/// keeps `Accent`, the color the page's theme puts behind it, and the tab
/// wears the image the issuer holds, which it offers with the intent; any
/// other choice drops the tab's image. Refused with `InvalidTabIcon` when the
/// mode can make no icon from what the intent gives.
public sealed record ChooseTabIcon(Guid WorkspaceId, Guid SpaceId, Guid TabId, TabIconMode Mode, string? Emoji,
    TabIconAccent? Accent) : SessionIntent(WorkspaceId);

/// Whether a tab's page stays loaded when memory runs low. Unloading it on
/// purpose still does, so this is a preference, not a promise.
public sealed record KeepPageLoaded(Guid WorkspaceId, Guid SpaceId, Guid TabId, bool Keeps) : SessionIntent(WorkspaceId);

/// Names a tab, over whatever its page calls itself. A blank or null title
/// hands the tab back to its page's title. Refused with `InvalidName` for a
/// name too long to keep.
public sealed record RenameTab(Guid WorkspaceId, Guid SpaceId, Guid TabId, string? Title) : SessionIntent(WorkspaceId);

/// Makes the page a saved or pinned tab shows the one it belongs to. A tab at
/// its saved address changes nothing. Refused with `NoSavedAddress` for a tab
/// that belongs nowhere.
public sealed record ReplaceSavedAddress(Guid WorkspaceId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);

/// Returns a saved or pinned tab to the address it belongs to, which its page
/// then loads. A tab already there changes nothing, and its page may still
/// load it. Refused with `NoSavedAddress` for a tab that belongs nowhere.
public sealed record ReturnToSavedAddress(Guid WorkspaceId, Guid SpaceId, Guid TabId) : SessionIntent(WorkspaceId);

#endregion

#region Rejections

/// `Mode` could make no icon from what the intent gave: an emoji icon needs an
/// emoji.
public sealed record InvalidTabIcon(TabIconMode Mode) : Rejection;

/// The tab belongs to no address: it is an open tab, which goes wherever
/// browsing takes it, or a saved or pinned one that shows no web page.
public sealed record NoSavedAddress(Guid TabId) : Rejection;

#endregion
