namespace CrestCore.Contracts;

/// A page's script dialog waits on the person.
public sealed record ScriptDialogAsked(Guid PromptId, Guid PageId, ScriptDialogQuestion Question) : Change;
