namespace CrestCore.Contracts;

/// A prompt no longer waits: the person answered it, its engine withdrew it,
/// or its page went.
public sealed record PromptSettled(Guid PromptId) : Change;
