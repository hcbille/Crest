namespace CrestCore.Contracts;

/// A document in a page opened a script dialog, which waits for the core's
/// `SettleScriptDialog`.
public sealed record ScriptDialogOpened(Guid PromptId, Guid PageId, ScriptDialogQuestion Question) : EngineEvent;
