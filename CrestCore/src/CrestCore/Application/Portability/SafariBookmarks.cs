using CrestCore.Contracts;

using static CrestCore.Application.PropertyListValue;

namespace CrestCore.Application;

/// Safari's `Bookmarks.plist`: a tree of leaves, each a link, and lists, each
/// a folder, below its top level.
internal static class SafariBookmarks {
    #region Static Variables

    private const string LeafType = "WebBookmarkTypeLeaf";

    #endregion

    #region Actions - Reading

    /// The bookmarks the file holds. A link without a usable time is dated
    /// `importedAt`. Throws `Rejected` with `BookmarksUnrecognized` for a file
    /// that is not Safari's bookmarks, and `BookmarksOverLimits` for one
    /// holding more than Crest keeps.
    public static BookmarkDraft Read(byte[] contents, DateTimeOffset importedAt) {
        var root = Dictionary(PropertyList.Read(contents));
        var children = Array(Member(root, "Children")) ?? throw new Rejected(new BookmarksUnrecognized());
        var draft = new BookmarkDraft();
        Append(children, parent: null, depth: 0, draft, importedAt);
        return draft;
    }

    private static void Append(IReadOnlyList<object> children, Guid? parent, int depth, BookmarkDraft draft, DateTimeOffset importedAt) {
        foreach (var child in children.Select(Dictionary).OfType<IReadOnlyDictionary<string, object>>()) {
            if (Text(Member(child, "WebBookmarkType")) == LeafType && Text(Member(child, "URLString")) is { } url) {
                string title = Text(Member(Dictionary(Member(child, "URIDictionary")), "title")) ?? Text(Member(child, "Title")) ?? "";
                var added = child.ContainsKey("DateAdded") ? Member(child, "DateAdded") : Member(child, "DateVisited");
                draft.AppendBookmark(title, url, parent, Added(added) ?? importedAt);
                continue;
            }
            if (Array(Member(child, "Children")) is not { } nested) continue;
            var folder = draft.AppendFolder(Text(Member(child, "Title")), parent, depth);
            Append(nested, folder, depth + 1, draft, importedAt);
        }
    }

    /// A time Safari keeps as a date, or as a number or a string in whichever
    /// unit its size suggests, when it is a positive, finite time.
    private static DateTimeOffset? Added(object? value) {
        if (value is PropertyListDate date) return ImportDate.FromReferenceSeconds(date.ReferenceSeconds);
        double? raw = Number(value) ?? (Text(value) is { } text ? ImportJson.SpelledNumber(text) : null);
        return raw is { } number && double.IsFinite(number) && number > 0 ? ImportDate.FromAnyUnit(number) : null;
    }

    #endregion
}
