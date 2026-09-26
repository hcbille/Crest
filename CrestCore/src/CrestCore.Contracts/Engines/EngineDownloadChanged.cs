namespace CrestCore.Contracts;

/// An engine download started, progressed, finished or failed. The core
/// records it in the download ledger, in the Space its page or profile belongs
/// to, and asks the person to keep a file the engine warned about.
public sealed record EngineDownloadChanged(EngineDownload Download) : EngineEvent;
