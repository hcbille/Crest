namespace CrestCore.Contracts;

/// Whether to install the extension package the engine verified: its
/// `Name`, `Version` and `Summary`, the `Permissions` it asks for, as the
/// engine words them, and its icon as PNG bytes. `CanWithholdSiteAccess` says
/// the person may keep its site access back, and `WithholdsSiteAccess` says
/// installing does so unless they choose otherwise.
public sealed record ExtensionInstallQuestion(string ExtensionId, string Name, string Version, string Summary,
    IReadOnlyList<string> Permissions, byte[]? Icon, bool CanWithholdSiteAccess, bool WithholdsSiteAccess);
