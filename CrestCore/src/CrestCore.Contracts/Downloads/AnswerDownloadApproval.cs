namespace CrestCore.Contracts;

/// Whether the person keeps a file the engine warned about. A file not kept
/// is cancelled.
public sealed record AnswerDownloadApproval(Guid PromptId, bool Approved) : PromptIntent(PromptId);
