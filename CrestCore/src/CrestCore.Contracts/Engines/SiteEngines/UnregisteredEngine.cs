namespace CrestCore.Contracts;

/// This device registered no engine of `Kind`, so no page can open on it.
public sealed record UnregisteredEngine(EngineKind Kind) : Rejection;
