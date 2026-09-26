namespace CrestCore.Contracts;

/// Whether to quit and stop the `LiveDownloads` downloads still in progress
/// waits on the person, for the quit preparation `RequestId`.
public sealed record QuitWithDownloadsAsked(Guid PromptId, Guid RequestId, int LiveDownloads) : Change;
