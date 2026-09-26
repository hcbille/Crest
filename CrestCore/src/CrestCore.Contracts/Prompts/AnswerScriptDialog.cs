namespace CrestCore.Contracts;

/// The person answered a script dialog: whether they accepted it, and the text
/// a prompt dialog took.
public sealed record AnswerScriptDialog(Guid PromptId, bool Accepted, string? Text) : PromptIntent(PromptId);
