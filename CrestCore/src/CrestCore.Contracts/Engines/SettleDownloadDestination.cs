namespace CrestCore.Contracts;

/// The file a download the engine asked about goes to, or none to cancel it.
/// Choosing where a file goes never overrides the engine's safety verdict.
public sealed record SettleDownloadDestination(Guid PromptId, string? Path) : EngineCommand;
