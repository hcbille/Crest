using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// One window or Space another browser's session holds, as its reader found
/// it: the folders and tabs, with the folder identities the browser spells,
/// and the name, symbol, accent and look it gave the Space, where it gave
/// any. `Ordinal` counts the browser's windows or Spaces from one.
internal sealed record SessionDraft(int Ordinal, string? Name, IReadOnlyList<SessionFolder> Folders, IReadOnlyList<SessionTab> Tabs,
    string? Symbol = null, SpaceAccent? Accent = null, SpaceBranding? Branding = null) {
    #region Static Variables

    /// The most tabs one window or Space brings.
    public const int MaximumTabs = BrowserDataSpace.MaximumTabs;

    private const string UntitledFolder = "Untitled Folder";

    #endregion

    #region Actions - Spaces

    /// The Spaces `drafts` make for `source`: each draft that holds a tab, named
    /// as the browser named it or else by `names`, with every record a new
    /// identity from `ids`. A tab with no usable time is dated `importedAt`.
    /// Throws `Rejected` with `SessionHasNoTabs` when no draft holds a tab,
    /// `SessionOverLimits` when they hold more than Crest keeps, and
    /// `SessionUnrecognized` for a folder the session names twice or cannot
    /// place.
    public static IReadOnlyList<SpaceState> Spaces(IReadOnlyList<SessionDraft> drafts, ImportSource source, ImportSpaceNames names,
        IIdSource ids, DateTimeOffset importedAt) {
        var kept = drafts.Where(draft => draft.Tabs.Count > 0).ToArray();
        if (kept.Length == 0) throw new Rejected(new SessionHasNoTabs());
        if (kept.Length > BrowserDataFile.MaximumSpaces || kept.Any(draft => draft.Tabs.Count > MaximumTabs))
            throw new Rejected(new SessionOverLimits());
        var spaces = kept.Select(draft => draft.Portable(source, names, numbered: kept.Length > 1, ids, importedAt)).ToArray();
        try {
            return [.. spaces.Select(space => space.Materialize(ids, importedAt))];
        } catch (Rejected rejected) when (rejected.Rejection is ArchiveInvalid) {
            throw new Rejected(new SessionOverLimits());
        }
    }

    /// The Space as a Crest browser-data file would keep it. Pinned tabs past
    /// the limit become saved tabs in an `Imported Pinned Tabs` folder.
    private BrowserDataSpace Portable(ImportSource source, ImportSpaceNames names, bool numbered, IIdSource ids,
        DateTimeOffset importedAt) {
        if (Folders.Count >= FolderTree.MaximumCount) throw new Rejected(new SessionOverLimits());
        Dictionary<string, Guid> folderIds = new(StringComparer.Ordinal);
        foreach (var folder in Folders)
            if (!folderIds.TryAdd(folder.SourceId, ids.Next())) throw new Rejected(new SessionUnrecognized());
        List<BrowserDataFolder> folders = [.. Folders.Select(folder => {
            Guid? parent = null;
            if (folder.ParentSourceId is { } parentSource)
                parent = parentSource != folder.SourceId && folderIds.TryGetValue(parentSource, out var mapped) ? mapped
                    : throw new Rejected(new SessionUnrecognized());
            string title = ImportText.Bounded(folder.Title, UntitledFolder, ImportText.MaximumFolderTitle)
                ?? throw new Rejected(new SessionOverLimits());
            return Folder(folderIds[folder.SourceId], title, FolderState.DefaultSymbol, parent);
        })];
        if (!IsForest(folders)) throw new Rejected(new SessionOverLimits());

        int pinned = 0;
        Guid? overflow = null;
        List<BrowserDataTab> tabs = [];
        foreach (var tab in Tabs) {
            var placement = tab.Placement;
            Guid? folder = tab.FolderSourceId is { } folderSource && folderIds.TryGetValue(folderSource, out var mapped) ? mapped : null;
            if (placement == TabPlacement.Saved && tab.FolderSourceId is not null && folder is null)
                throw new Rejected(new SessionUnrecognized());
            if (placement == TabPlacement.Pinned && pinned < TabPlacement.PinnedCapacity) {
                pinned++;
            } else if (placement == TabPlacement.Pinned) {
                placement = TabPlacement.Saved;
                if (overflow is null) {
                    overflow = ids.Next();
                    folders.Add(Folder(overflow.Value, WorkspaceImportPolicy.OverflowFolderTitle, WorkspaceImportPolicy.OverflowFolderSymbol,
                        parent: null));
                }
                folder = overflow;
            }
            string title = ImportText.Bounded(tab.Title, tab.Address.Host, ImportText.MaximumTitle)
                ?? throw new Rejected(new SessionOverLimits());
            string url = tab.Address.Spelling;
            tabs.Add(new(ids.Next(), title, NativeContent: null, url, placement.IsDurable ? url : null,
                placement == TabPlacement.Pinned ? WorkspaceImportPolicy.PinnedTabSymbol : TabIconMode.WebSymbol, placement,
                placement == TabPlacement.Saved ? folder : null, SplitGroupId: null, tab.LastActivatedAt ?? importedAt));
        }

        string fallback = numbered ? names.NumberedSpaceName.Replace("%lld", Ordinal.ToString(System.Globalization.CultureInfo.InvariantCulture),
            StringComparison.Ordinal) : names.SpaceName;
        string name = ImportText.Bounded(Name, fallback, ImportText.MaximumSpaceName) ?? throw new Rejected(new SessionOverLimits());
        string symbol = Symbol ?? source.Symbol;
        return new(name, symbol, Accent ?? source.Accent, Branding ?? ImportedLook.Neutral(symbol), Ordered(folders), tabs,
            Splits: [], ArchivedTabs: [], History: [], StoredSessionCodec.DefaultBrowsingPreferences, SelectedTabId: null);
    }

    /// A saved folder in the default color.
    private static BrowserDataFolder Folder(Guid id, string title, string symbol, Guid? parent) =>
        new(id, TabPlacement.Saved, title, symbol, FolderState.DefaultColor, parent, IsCollapsed: false, OrderAnchorTabId: null);

    private static bool IsForest(IReadOnlyList<BrowserDataFolder> folders) {
        try {
            _ = new FolderTree([.. folders.Select(folder => folder.Materialize(folder.Id, folder.ParentId))]).DisplayOrder();
            return true;
        } catch (Exception error) when (error is BrowserRuleException or Rejected) {
            return false;
        }
    }

    /// `folders`, each parent before its children.
    private static IReadOnlyList<BrowserDataFolder> Ordered(IReadOnlyList<BrowserDataFolder> folders) {
        var order = new FolderTree([.. folders.Select(folder => folder.Materialize(folder.Id, folder.ParentId))]).DisplayOrder();
        var byId = folders.ToDictionary(folder => folder.Id);
        return [.. order.Select(folder => byId[folder.Id])];
    }

    #endregion
}
