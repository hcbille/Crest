namespace CrestCore.Contracts;

/// The engine's page is gone: the core asked the engine to close it, or the
/// page closed itself, as `window.close()` does. A page closed keeping its
/// state hands back what brings it back, when its engine can.
public sealed record PageClosed(Guid PageId, PageRestoreState? RestoreState) : EngineEvent;
