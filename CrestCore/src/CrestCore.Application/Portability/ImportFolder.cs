using System.Text.Json;

namespace CrestCore.Application;

/// A folder where another browser keeps its data, as an import searches it:
/// its files and folders, without hidden ones or links, and a folder that is
/// missing or unreadable holding nothing.
internal readonly record struct ImportFolder(string Path) {
    #region Static Variables

    private static readonly EnumerationOptions Flat = new() {
        AttributesToSkip = FileAttributes.Hidden | FileAttributes.System | FileAttributes.ReparsePoint,
        IgnoreInaccessible = true
    };

    private static readonly EnumerationOptions Deep = new() {
        AttributesToSkip = FileAttributes.Hidden | FileAttributes.System | FileAttributes.ReparsePoint,
        IgnoreInaccessible = true,
        RecurseSubdirectories = true
    };

    #endregion

    #region Variables

    /// The name of this folder.
    public string Name => System.IO.Path.GetFileName(System.IO.Path.TrimEndingDirectorySeparator(Path));

    #endregion

    #region Actions - Searching

    /// The folder named `name` inside this one.
    public ImportFolder Child(string name) => new(System.IO.Path.Combine(Path, name));

    /// The file `name` inside this folder, where it is a file.
    public string? File(string name) {
        string path = System.IO.Path.Combine(Path, name);
        return System.IO.File.Exists(path) ? path : null;
    }

    /// The folders inside this one, in the order of their names.
    public IReadOnlyList<ImportFolder> Folders() {
        try {
            return [.. Directory.EnumerateDirectories(Path, "*", Flat).Order(StringComparer.Ordinal).Select(path => new ImportFolder(path))];
        } catch (Exception error) when (error is IOException or UnauthorizedAccessException) {
            return [];
        }
    }

    /// The most recently changed file at any depth below this folder whose
    /// name is one of `names` or starts with one of `prefixes`.
    public string? Newest(IReadOnlyCollection<string> names, IReadOnlyCollection<string>? prefixes = null) {
        try {
            return Directory.EnumerateFiles(Path, "*", Deep)
                .Where(path => {
                    string name = System.IO.Path.GetFileName(path);
                    return names.Contains(name) || (prefixes ?? []).Any(prefix => name.StartsWith(prefix, StringComparison.Ordinal));
                })
                .Order(StringComparer.Ordinal)
                .Select(path => (Path: path, Changed: System.IO.File.GetLastWriteTimeUtc(path)))
                .Aggregate(((string Path, DateTime Changed)?)null, (newest, file) => newest is null || file.Changed > newest.Value.Changed
                    ? file : newest)?.Path;
        } catch (Exception error) when (error is IOException or UnauthorizedAccessException) {
            return null;
        }
    }

    /// The JSON file `name` inside this folder, or null when it is missing or
    /// not JSON.
    public JsonDocument? Json(string name) {
        if (File(name) is not { } path) return null;
        try {
            return ImportJson.Parse(System.IO.File.ReadAllBytes(path));
        } catch (Exception error) when (error is IOException or UnauthorizedAccessException) {
            return null;
        }
    }

    #endregion
}
