namespace CrestCore.Contracts;

/// The file the download `EngineDownloadDestinationRequested` asked about goes
/// to, or none to cancel it.
public sealed record AnswerEngineDownloadDestination(Guid RequestId, string? Path) : PageRequest<bool>;
