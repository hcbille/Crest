namespace CrestCore.Contracts;

/// The page began loading a new document; what the platform keeps for the
/// document it shows now is about to go stale.
public sealed record PageNavigationStarted(Guid PageId) : EnginePresentation;
