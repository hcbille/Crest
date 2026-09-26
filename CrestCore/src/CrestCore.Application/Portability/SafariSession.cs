using CrestCore.Contracts;
using CrestCore.Domain;

using static CrestCore.Application.PropertyListValue;

namespace CrestCore.Application;

/// Safari's last session, `LastSession.plist`: its windows with their tabs,
/// the selected window first. The keys Safari has used for windows, tabs and
/// their members changed across releases, so each is found among the
/// spellings Safari used; a list without windows is searched for anything
/// that names an address.
internal static class SafariSession {
    #region Static Variables

    private static readonly string[] WindowKeys = ["Windows", "SessionWindows", "BrowserWindows", "OrderedWindows"];
    private static readonly string[] TabKeys = ["Tabs", "SessionTabs", "TabStates", "OrderedTabs", "Children"];
    private static readonly string[] AddressKeys = ["URL", "URLString", "TabURL", "CurrentURL", "SessionTabURL", "url"];
    private static readonly string[] TitleKeys = ["Title", "TabTitle", "PageTitle", "title"];
    private static readonly string[] NestedStateKeys = ["TabState", "SessionState", "PageState", "URIDictionary"];
    private static readonly string[] SelectedWindowKeys = ["SelectedWindowIndex", "SelectedWindow", "selectedWindow"];
    private static readonly string[] WindowTitleKeys = ["Title", "Name", "WindowTitle"];
    private static readonly string[] SessionTitleKeys = ["Title", "Name"];
    private static readonly string[] PinnedKeys = ["Pinned", "IsPinned", "pinned"];
    private static readonly string[] TimeKeys = ["LastActive", "LastAccessed", "DateVisited", "lastAccessed"];

    #endregion

    #region Actions - Reading

    /// The windows the session holds. Throws `Rejected` with
    /// `SessionUnrecognized` for a file that is not a property list, and
    /// `SessionOverLimits` for a window holding more than Crest keeps.
    public static IReadOnlyList<SessionDraft> Read(byte[] contents, DateTimeOffset importedAt) {
        var list = PropertyList.Read(contents) ?? throw new Rejected(new SessionUnrecognized());
        var root = Dictionary(list);
        if (((root is null ? null : FirstArray(root, WindowKeys)) ?? Array(list)) is { } windows) {
            List<SessionDraft> drafts = [];
            for (int index = 0; index < windows.Count; index++)
                if (Dictionary(windows[index]) is { } window) drafts.Add(Window(window, index + 1, importedAt));
            return Reordered(drafts, root is null ? null : FirstInteger(root, SelectedWindowKeys));
        }
        List<IReadOnlyDictionary<string, object>> found = [];
        Collect(list, depth: 0, found);
        return [new SessionDraft(1, root is null ? null : FirstText(root, SessionTitleKeys), [],
            [.. found.Select(tab => Tab(tab, importedAt)).OfType<SessionTab>()])];
    }

    private static SessionDraft Window(IReadOnlyDictionary<string, object> window, int ordinal, DateTimeOffset importedAt) {
        var tabs = FirstArray(window, TabKeys) ?? [];
        if (tabs.Count > SessionDraft.MaximumTabs) throw new Rejected(new SessionOverLimits());
        return new SessionDraft(ordinal, FirstText(window, WindowTitleKeys), [],
            [.. tabs.Select(tab => Dictionary(tab) is { } found ? Tab(found, importedAt) : null).OfType<SessionTab>()]);
    }

    private static SessionTab? Tab(IReadOnlyDictionary<string, object> tab, DateTimeOffset importedAt) {
        var nested = NestedStateKeys.Select(key => Dictionary(Member(tab, key))).FirstOrDefault(value => value is not null);
        if ((FirstText(tab, AddressKeys) ?? FirstText(nested, AddressKeys)) is not { } url || ImportAddress.Read(url) is not { } address)
            return null;
        string title = FirstText(tab, TitleKeys) ?? FirstText(nested, TitleKeys) ?? "";
        bool pinned = FirstFlag(tab, PinnedKeys) ?? false;
        return new SessionTab(title, address, pinned ? TabPlacement.Pinned : TabPlacement.Current, FolderSourceId: null,
            Time(tab) ?? importedAt);
    }

    /// The first of the time keys holding a date, or a number of seconds or
    /// milliseconds since 1970.
    private static DateTimeOffset? Time(IReadOnlyDictionary<string, object> tab) {
        foreach (string key in TimeKeys) {
            var value = Member(tab, key);
            if (value is PropertyListDate date) return ImportDate.FromReferenceSeconds(date.ReferenceSeconds);
            if (Number(value) is { } raw) return ImportDate.FromUnixSecondsOrMilliseconds(raw);
        }
        return null;
    }

    /// Every dictionary below `value` that names an address, searched in the
    /// order the list holds them, up to the depth folders nest and the tabs a
    /// window holds.
    private static void Collect(object value, int depth, List<IReadOnlyDictionary<string, object>> found) {
        if (depth >= FolderTree.MaximumDepth || found.Count >= SessionDraft.MaximumTabs) return;
        if (Dictionary(value) is { } dictionary) {
            if (FirstText(dictionary, AddressKeys) is not null) {
                found.Add(dictionary);
                return;
            }
            foreach (var nested in dictionary.Values) Collect(nested, depth + 1, found);
            return;
        }
        if (Array(value) is { } items)
            foreach (var nested in items) Collect(nested, depth + 1, found);
    }

    /// The drafts with the one Safari had selected, counted from one, first.
    private static List<SessionDraft> Reordered(List<SessionDraft> drafts, long? selected) {
        if (selected is null) return drafts;
        long ordinal = selected > 0 ? selected.Value : 1;
        if (drafts.FindIndex(draft => draft.Ordinal == ordinal) is > 0 and var index) {
            var first = drafts[index];
            drafts.RemoveAt(index);
            drafts.Insert(0, first);
        }
        return drafts;
    }

    #endregion
}
