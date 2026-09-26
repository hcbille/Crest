namespace CrestCore.Contracts;

/// The person answered whether to install an extension, and whether it
/// installs with its site access withheld.
public sealed record AnswerExtensionInstall(Guid PromptId, bool Accepted, bool WithholdsSiteAccess) : PromptIntent(PromptId);
