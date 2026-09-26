namespace CrestCore.Contracts;

/// Where the file of a download goes, as the platform resolved it or the person
/// chose it, or none to cancel the download.
public sealed record AnswerDownloadDestination(Guid PromptId, string? Path) : PromptIntent(PromptId);
