namespace CrestCore.Contracts;

/// One installed extension: what it is, its icon as a PNG, whether it is
/// enabled, the permission warnings it carries, whether it came from the
/// Chrome Web Store, and its options page, if it has one.
public sealed record InstalledExtension(string Id, string Name, string Version, string Description, byte[]? Icon,
    bool Enabled, IReadOnlyList<string> Permissions, bool FromWebStore, string? OptionsUrl);
