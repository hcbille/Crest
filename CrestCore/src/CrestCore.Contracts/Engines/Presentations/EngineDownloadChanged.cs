namespace CrestCore.Contracts;

/// An engine download started, progressed, finished or failed.
public sealed record EngineDownloadChanged(EngineDownload Download) : EnginePresentation;
