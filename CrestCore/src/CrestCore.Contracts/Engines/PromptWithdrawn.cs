namespace CrestCore.Contracts;

/// The engine no longer waits for a prompt's answer: the page moved on, or
/// what asked went away.
public sealed record PromptWithdrawn(Guid PromptId) : EngineEvent;
