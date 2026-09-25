namespace CrestCore.Contracts;

/// Installed extensions, as an engine lists them.
public sealed record InstalledExtensionList(IReadOnlyList<InstalledExtension> Extensions);
