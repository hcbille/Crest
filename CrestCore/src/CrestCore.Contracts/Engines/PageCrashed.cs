namespace CrestCore.Contracts;

/// A page's renderer stopped: it crashed, or the system ended it. The document
/// it showed is gone, and the core decides whether the engine brings it back.
/// `Domain` and `Code` are the engine's own reason, which a failure page shows
/// as technical details and nothing branches on.
public sealed record PageCrashed(Guid PageId, string Domain, long Code) : EngineEvent;
