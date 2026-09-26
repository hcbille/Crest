namespace CrestCore.Contracts;

/// The intent names a prompt that no longer waits.
public sealed record UnknownPrompt(Guid PromptId) : Rejection;
