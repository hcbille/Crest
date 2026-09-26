namespace CrestCore.Contracts;

/// Whether to keep the file of the download `DownloadId`, which the engine
/// warned about for `Warning`, waits on the person.
public sealed record DownloadApprovalAsked(Guid PromptId, Guid DownloadId, string Filename, EngineDownloadWarning Warning)
    : Change;
