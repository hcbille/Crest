namespace CrestCore.Contracts;

/// Answers a permission request: whether it `Grants` it, and whether the
/// answer holds for the site's later requests or this one alone.
public sealed record SettlePermission(Guid PromptId, bool Grants, bool Remembers) : EngineCommand;
