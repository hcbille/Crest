namespace CrestCore.Contracts;

/// Installs the extension the prompt asked about, with its site access
/// withheld when asked, or cancels the install.
public sealed record SettleExtensionInstall(Guid PromptId, bool Accepted, bool WithholdsSiteAccess) : EngineCommand;
