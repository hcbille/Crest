using System.Text.Json;

using CrestCore.Contracts;

namespace CrestCore.Application;

/// Firefox's session, `recovery.jsonlz4` or `sessionstore.jsonlz4`: its
/// windows, each with its open and pinned tabs, the window it had selected
/// first.
internal static class FirefoxSession {
    #region Actions - Reading

    /// The windows the session holds. Throws `Rejected` with
    /// `SessionUnrecognized` for a file that is not Firefox's session, and
    /// `SessionOverLimits` for one holding more than Crest keeps.
    public static IReadOnlyList<SessionDraft> Read(byte[] contents, DateTimeOffset importedAt) {
        using var document = ImportJson.Parse(MozillaLz4.Decoded(contents)) ?? throw new Rejected(new SessionUnrecognized());
        var root = ImportJson.Object(document.RootElement);
        var windows = ImportJson.Array(ImportJson.Member(root, "windows"));
        if (root is null || windows is null || windows.Count > BrowserDataFile.MaximumSpaces) throw new Rejected(new SessionUnrecognized());
        List<SessionDraft> drafts = [];
        for (int index = 0; index < windows.Count; index++) {
            var window = windows[index];
            if (ImportJson.Object(window) is null || ImportJson.Array(ImportJson.Member(window, "tabs")) is not { } tabs) continue;
            if (tabs.Count > SessionDraft.MaximumTabs) throw new Rejected(new SessionOverLimits());
            drafts.Add(new SessionDraft(index + 1, ImportJson.Text(ImportJson.Member(window, "title")), [],
                [.. tabs.Select(tab => Tab(tab, importedAt)).OfType<SessionTab>()]));
        }
        long selected = Math.Max(1, ImportJson.Integer(ImportJson.Member(root, "selectedWindow")) ?? 1);
        if (drafts.FindIndex(draft => draft.Ordinal == selected) is > 0 and var first) {
            var draft = drafts[first];
            drafts.RemoveAt(first);
            drafts.Insert(0, draft);
        }
        return drafts;
    }

    /// The page a tab shows: its selected history entry.
    private static SessionTab? Tab(JsonElement tab, DateTimeOffset importedAt) {
        if (ImportJson.Object(tab) is null || ImportJson.Array(ImportJson.Member(tab, "entries")) is not { Count: > 0 } entries) return null;
        long selected = Math.Min(Math.Max(0, (ImportJson.Integer(ImportJson.Member(tab, "index")) ?? 1) - 1), entries.Count - 1);
        var entry = entries[(int)selected];
        if (ImportJson.Object(entry) is null || ImportJson.Text(ImportJson.Member(entry, "url")) is not { } url
            || ImportAddress.Read(url) is not { } address) return null;
        var time = ImportJson.Number(ImportJson.Member(tab, "lastAccessed")) is { } raw ? ImportDate.FromUnixMilliseconds(raw) : null;
        bool pinned = ImportJson.Flag(ImportJson.Member(tab, "pinned")) ?? false;
        return new SessionTab(ImportJson.Text(ImportJson.Member(entry, "title")) ?? "", address,
            pinned ? TabPlacement.Pinned : TabPlacement.Current, FolderSourceId: null, time ?? importedAt);
    }

    #endregion
}
