namespace CrestCore.Contracts;

/// The answer is not of the kind the prompt asks for.
public sealed record PromptAnswerMismatch(Guid PromptId) : Rejection;
