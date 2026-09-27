using System.Globalization;
using System.Text.Json;

using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Zen's `zen-sessions.jsonlz4`: its Spaces, folders and tabs. Each Space
/// brings the Essentials as pinned tabs, its pinned tabs as saved tabs in
/// their folders, and its other tabs as open tabs, with its name and theme.
internal static class ZenSessions {
    #region Static Variables

    private const string Symbol = "circle.hexagongrid.fill";
    private const string UntitledFolder = "Untitled Folder";
    private const double DefaultOpacity = 0.65;

    #endregion

    #region Actions - Reading

    /// The Spaces the session holds, in order. Throws `Rejected` with
    /// `SessionUnrecognized` for a file that is not Zen's session, and
    /// `SessionOverLimits` for one holding more than Crest keeps.
    public static IReadOnlyList<SessionDraft> Read(byte[] contents, DateTimeOffset importedAt) {
        using var document = ImportJson.Parse(MozillaLz4.Decoded(contents)) ?? throw new Rejected(new SessionUnrecognized());
        var root = ImportJson.Object(document.RootElement) ?? throw new Rejected(new SessionUnrecognized());
        var spaces = ImportJson.Array(ImportJson.Member(root, "spaces"));
        var tabs = ImportJson.Array(ImportJson.Member(root, "tabs"));
        if (spaces is null || tabs is null || spaces.Count == 0 || spaces.Count > BrowserDataFile.MaximumSpaces
            || tabs.Count > SessionDraft.MaximumTabs * spaces.Count) throw new Rejected(new SessionUnrecognized());
        var folders = ImportJson.Array(ImportJson.Member(root, "folders")) ?? [];
        if (folders.Count > FolderTree.MaximumCount * spaces.Count) throw new Rejected(new SessionOverLimits());

        List<SessionDraft> drafts = [];
        for (int index = 0; index < spaces.Count; index++) {
            var space = spaces[index];
            if (ImportJson.Object(space) is null || ImportJson.Text(ImportJson.Member(space, "uuid")) is not { } workspace) continue;
            var spaceFolders = folders.Where(folder => ImportJson.Object(folder) is not null
                    && (ImportJson.Text(ImportJson.Member(folder, "workspaceId")) ?? ImportJson.Text(ImportJson.Member(folder, "workspaceID")))
                    == workspace && ImportJson.Text(ImportJson.Member(folder, "id")) is not null)
                .Select(folder => new SessionFolder(ImportJson.Text(ImportJson.Member(folder, "id"))!,
                    ImportJson.Text(ImportJson.Member(folder, "name")) ?? UntitledFolder,
                    ImportJson.Text(ImportJson.Member(folder, "parentId")) ?? ImportJson.Text(ImportJson.Member(folder, "parentID"))))
                .ToArray();
            List<SessionTab> spaceTabs = [];
            foreach (var tab in tabs.Where(tab => ImportJson.Object(tab) is not null)) {
                var owner = ImportJson.Text(ImportJson.Member(tab, "zenWorkspace"));
                bool essential = ImportJson.Flag(ImportJson.Member(tab, "zenEssential")) ?? false;
                if ((owner == workspace || (owner is null && essential)) && Tab(tab, importedAt) is { } decoded) spaceTabs.Add(decoded);
            }
            if (spaceTabs.Count > SessionDraft.MaximumTabs) throw new Rejected(new SessionOverLimits());
            var theme = ImportJson.Member(space, "theme");
            var colors = Colors(theme);
            drafts.Add(new SessionDraft(index + 1, ImportJson.Text(ImportJson.Member(space, "name")) ?? $"Zen Space {index + 1}",
                spaceFolders, spaceTabs, Symbol, colors.Count == 0 ? SpaceAccent.Indigo : SpaceAccent.Nearest(colors[0]),
                Look(colors, theme)));
        }
        return drafts;
    }

    /// The page a tab shows: its selected history entry. Essentials are
    /// pinned tabs, and pinned tabs are saved tabs in their folder.
    private static SessionTab? Tab(JsonElement tab, DateTimeOffset importedAt) {
        if (ImportJson.Array(ImportJson.Member(tab, "entries")) is not { Count: > 0 } entries) return null;
        long selected = Math.Min(Math.Max(0, (ImportJson.Integer(ImportJson.Member(tab, "index")) ?? 1) - 1), entries.Count - 1);
        var entry = entries[(int)selected];
        if (ImportJson.Object(entry) is null || ImportJson.Text(ImportJson.Member(entry, "url")) is not { } url
            || ImportAddress.Read(url) is not { } address) return null;
        bool essential = ImportJson.Flag(ImportJson.Member(tab, "zenEssential")) ?? false;
        bool pinned = ImportJson.Flag(ImportJson.Member(tab, "pinned")) ?? false;
        var placement = essential ? TabPlacement.Pinned : pinned ? TabPlacement.Saved : TabPlacement.Current;
        var time = ImportJson.Number(ImportJson.Member(tab, "lastAccessed")) is { } raw ? ImportDate.FromUnixSecondsOrMilliseconds(raw) : null;
        return new SessionTab(ImportJson.Text(ImportJson.Member(entry, "title")) ?? "", address, placement,
            placement == TabPlacement.Saved ? ImportJson.Text(ImportJson.Member(tab, "groupId")) : null, time ?? importedAt);
    }

    #endregion

    #region Actions - Looks

    /// The theme's gradient colors, spelled as hex or as components, at most
    /// as many as a look keeps.
    private static List<BrandColor> Colors(JsonElement? theme) {
        var values = ImportJson.Object(theme) is null ? null : ImportJson.Array(ImportJson.Member(theme, "gradientColors"));
        return [.. (values ?? []).Select(Color).OfType<BrandColor>().Take(SpaceBrandingPolicy.MaximumColorCount)];
    }

    private static BrandColor? Color(JsonElement value) {
        if (ImportJson.Text(value) is { } hex) {
            string digits = hex.Trim('#');
            return digits.Length == 6 && int.TryParse(digits, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out int raw)
                ? new(((raw >> 16) & 0xFF) / 255.0, ((raw >> 8) & 0xFF) / 255.0, (raw & 0xFF) / 255.0) : null;
        }
        return ImportJson.Object(value) is not null && ImportJson.Number(ImportJson.Member(value, "red")) is { } red
            && ImportJson.Number(ImportJson.Member(value, "green")) is { } green
            && ImportJson.Number(ImportJson.Member(value, "blue")) is { } blue
            ? new(Math.Clamp(red, 0, 1), Math.Clamp(green, 0, 1), Math.Clamp(blue, 0, 1)) : null;
    }

    /// A gradient banner in bands of several colors, or a solid banner of
    /// one, as strong as the theme's opacity and textured as it is.
    private static SpaceBranding? Look(IReadOnlyList<BrandColor> colors, JsonElement? theme) => colors.Count == 0 ? null
        : ImportedLook.Painted(colors, colors.Count > 1 ? SpaceBannerPattern.Bands : SpaceBannerPattern.Solid,
            Math.Clamp(ImportJson.Number(ImportJson.Member(theme, "opacity")) ?? DefaultOpacity, 0, 1), ImportedLook.ReadableFade,
            SpaceThemeMode.Gradient, gradientAngle: 45, showsTexture: (ImportJson.Integer(ImportJson.Member(theme, "texture")) ?? 0) != 0);

    #endregion
}
