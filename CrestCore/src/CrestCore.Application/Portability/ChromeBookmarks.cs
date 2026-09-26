using System.Text.Json;

using CrestCore.Contracts;

namespace CrestCore.Application;

/// A Chromium profile's `Bookmarks` JSON: its roots, the bookmarks bar, other
/// and mobile bookmarks first, each a folder of links and folders, with times
/// in microseconds since 1601.
internal static class ChromeBookmarks {
    #region Static Variables

    /// The roots Chrome shows, in the order it shows them; others follow in
    /// the order of their names.
    private static readonly string[] PreferredRoots = ["bookmark_bar", "other", "synced"];

    private const string LinkType = "url";
    private const string FolderType = "folder";

    #endregion

    #region Actions - Reading

    /// The bookmarks the file holds. A link without a usable time is dated
    /// `importedAt`. Throws `Rejected` with `BookmarksUnrecognized` for a file
    /// that is not Chrome's bookmarks, and `BookmarksOverLimits` for one
    /// holding more than Crest keeps.
    public static BookmarkDraft Read(byte[] contents, DateTimeOffset importedAt) {
        using var document = ImportJson.Parse(contents) ?? throw new Rejected(new BookmarksUnrecognized());
        var roots = ImportJson.Object(ImportJson.Member(ImportJson.Object(document.RootElement), "roots"))
            ?? throw new Rejected(new BookmarksUnrecognized());
        var draft = new BookmarkDraft();
        var remaining = ImportJson.Members(roots).Select(member => member.Name).Where(name => !PreferredRoots.Contains(name))
            .Order(StringComparer.Ordinal);
        foreach (string key in PreferredRoots.Concat(remaining))
            if (ImportJson.Object(ImportJson.Member(roots, key)) is { } node) Append(node, parent: null, depth: 0, draft, importedAt);
        return draft;
    }

    private static void Append(JsonElement? node, Guid? parent, int depth, BookmarkDraft draft, DateTimeOffset importedAt) {
        string? type = ImportJson.Text(ImportJson.Member(node, "type"));
        if (type == LinkType && ImportJson.Text(ImportJson.Member(node, "url")) is { } url) {
            draft.AppendBookmark(ImportJson.Text(ImportJson.Member(node, "name")) ?? "", url, parent,
                Added(ImportJson.Member(node, "date_added")) ?? importedAt);
            return;
        }
        var childrenMember = ImportJson.Member(node, "children");
        if ((type != FolderType && childrenMember is null) || ImportJson.Array(childrenMember) is not { } children) return;
        var folder = draft.AppendFolder(ImportJson.Text(ImportJson.Member(node, "name")), parent, depth);
        foreach (var child in children.Where(child => child.ValueKind == JsonValueKind.Object))
            Append(child, folder, depth + 1, draft, importedAt);
    }

    /// A time Chrome spells as a number or a string of microseconds since
    /// 1601, when it is a positive, finite time.
    private static DateTimeOffset? Added(JsonElement? value) {
        double? raw = ImportJson.Number(value) ?? (ImportJson.Text(value) is { } text ? ImportJson.SpelledNumber(text) : null);
        return raw is { } number && double.IsFinite(number) && number > 0 ? ImportDate.FromWindowsMicroseconds(number) : null;
    }

    #endregion
}
