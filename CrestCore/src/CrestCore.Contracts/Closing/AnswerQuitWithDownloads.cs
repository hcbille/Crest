namespace CrestCore.Contracts;

/// Whether the person quits and stops the downloads in progress.
public sealed record AnswerQuitWithDownloads(Guid PromptId, bool Quits) : PromptIntent(PromptId);
