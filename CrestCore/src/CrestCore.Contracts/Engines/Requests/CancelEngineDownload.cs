namespace CrestCore.Contracts;

/// Cancels an engine download.
public sealed record CancelEngineDownload(Guid ProfileId, string DownloadId) : PageRequest<bool>;
