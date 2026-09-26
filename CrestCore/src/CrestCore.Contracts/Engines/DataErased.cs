namespace CrestCore.Contracts;

/// An erasure the core asked for ended: `Erased` says nothing it covered is
/// left.
public sealed record DataErased(Guid ErasureId, bool Erased) : EngineEvent;
