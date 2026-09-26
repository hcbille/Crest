namespace CrestCore.Contracts;

/// An extension install the window `WindowId` started needs the person's
/// approval, which waits for the core's `SettleExtensionInstall`.
public sealed record ExtensionInstallRequested(Guid PromptId, Guid WindowId, ExtensionInstallQuestion Question) : EngineEvent;
