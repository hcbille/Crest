namespace CrestCore.Contracts;

/// Removes a finished or stopped engine download from the engine's list.
public sealed record RemoveEngineDownload(Guid ProfileId, string DownloadId) : EngineCommand;
