namespace CrestCore.Contracts;

/// Closes a script dialog as the person answered it, or declined when no one
/// could.
public sealed record SettleScriptDialog(Guid PromptId, bool Accepted, string? Text) : EngineCommand;
