namespace CrestCore.Contracts;

/// Whether to install an extension waits on the person, in the window that
/// started the install.
public sealed record ExtensionInstallAsked(Guid PromptId, Guid WindowId, ExtensionInstallQuestion Question) : Change;
