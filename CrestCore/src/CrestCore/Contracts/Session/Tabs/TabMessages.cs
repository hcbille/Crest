namespace CrestCore.Contracts;

#region Rejections

/// `Mode` could make no icon from what the intent gave: an emoji icon needs an
/// emoji.
public sealed record InvalidTabIcon(TabIconMode Mode) : Rejection;

/// The tab belongs to no address: it is an open tab, which goes wherever
/// browsing takes it, or a saved or pinned one that shows no web page.
public sealed record NoSavedAddress(Guid TabId) : Rejection;

#endregion
