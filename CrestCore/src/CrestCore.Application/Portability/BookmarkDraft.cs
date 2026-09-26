using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Another browser's bookmarks as a reader finds them: folders and links in
/// order, each link kept where it names a web page. They become one Space of
/// saved tabs in saved folders.
internal sealed class BookmarkDraft {
    #region Static Variables

    /// The most links one browser's bookmarks bring.
    public const int MaximumBookmarks = 5_000;

    private const string UntitledFolder = "Untitled Folder";
    private const string BookmarkSymbol = "book.closed";

    #endregion

    #region Types

    private sealed record Folder(Guid Id, string Title, Guid? Parent);

    private sealed record Bookmark(string Title, ImportAddress Address, Guid? Folder, DateTimeOffset AddedAt);

    #endregion

    #region Variables

    private readonly List<Folder> folders = [];
    private readonly List<Bookmark> bookmarks = [];

    #endregion

    #region Actions - Reading

    /// Adds a folder `depth` folders deep and answers its identity. Throws
    /// `Rejected` with `BookmarksOverLimits` past the folders or nesting a
    /// Space keeps, or for a title longer than a folder keeps.
    public Guid AppendFolder(string? title, Guid? parent, int depth) {
        if (depth >= FolderTree.MaximumDepth || folders.Count >= FolderTree.MaximumCount)
            throw new Rejected(new BookmarksOverLimits());
        var folder = new Folder(Guid.NewGuid(),
            ImportText.Bounded(title, UntitledFolder, ImportText.MaximumFolderTitle) ?? throw new Rejected(new BookmarksOverLimits()),
            parent);
        folders.Add(folder);
        return folder.Id;
    }

    /// Adds a link to `url`, unless it names no web page. Throws `Rejected`
    /// with `BookmarksOverLimits` past the links a Space brings, or for a title
    /// longer than a tab keeps.
    public void AppendBookmark(string? title, string url, Guid? folder, DateTimeOffset addedAt) {
        if (bookmarks.Count >= MaximumBookmarks) throw new Rejected(new BookmarksOverLimits());
        if (ImportAddress.Read(url) is not { } address) return;
        bookmarks.Add(new Bookmark(
            ImportText.Bounded(title, address.Host, ImportText.MaximumTitle) ?? throw new Rejected(new BookmarksOverLimits()),
            address, folder, addedAt));
    }

    #endregion

    #region Actions - Spaces

    /// The Space the bookmarks make for `source`, named after it, every record
    /// a new identity from `ids`. Throws `Rejected` with `BookmarksHaveNoLinks`
    /// when no link names a web page, `BookmarksOverLimits` for folders a
    /// Space would not keep, and `BookmarksUnrecognized` for anything else a
    /// Space would not keep.
    public SpaceState Space(ImportSource source, IIdSource ids, DateTimeOffset now) {
        ArgumentNullException.ThrowIfNull(source);
        if (bookmarks.Count == 0) throw new Rejected(new BookmarksHaveNoLinks());
        var kept = folders.Select(folder => new BrowserDataFolder(folder.Id, TabPlacement.Saved, folder.Title, FolderState.DefaultSymbol,
            FolderState.DefaultColor, folder.Parent, IsCollapsed: false, OrderAnchorTabId: null)).ToArray();
        IReadOnlyList<FolderState> ordered;
        try {
            ordered = new FolderTree([.. kept.Select(folder => folder.Materialize(folder.Id, folder.ParentId))]).DisplayOrder();
        } catch (Exception error) when (error is BrowserRuleException or Rejected) {
            throw new Rejected(new BookmarksOverLimits());
        }
        var byId = kept.ToDictionary(folder => folder.Id);
        var tabs = bookmarks.Select(bookmark => new BrowserDataTab(Guid.NewGuid(), bookmark.Title, NativeContent: null,
            bookmark.Address.Spelling, bookmark.Address.Spelling, BookmarkSymbol, TabPlacement.Saved, bookmark.Folder, SplitGroupId: null,
            bookmark.AddedAt)).ToArray();
        var space = new BrowserDataSpace(source.Title, source.Symbol,
            source.Accent, Branding: null, [.. ordered.Select(folder => byId[folder.Id])], tabs, Splits: [], ArchivedTabs: [], History: [],
            StoredSessionCodec.DefaultBrowsingPreferences, SelectedTabId: null);
        try {
            return space.Materialize(ids, now);
        } catch (Rejected rejected) when (rejected.Rejection is ArchiveInvalid) {
            throw new Rejected(new BookmarksUnrecognized());
        }
    }

    #endregion
}
