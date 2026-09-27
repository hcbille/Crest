using CrestCore.Application;

namespace CrestCore.Contracts;

/// An erasure the core asked for ended: `Erased` says nothing it covered is
/// left.
public sealed record DataErased(Guid ErasureId, bool Erased) : EngineEvent {
    #region Actions - Routing

    internal override void Route(CrestApp app, Engine engine, ChangeFeed changes) => app.DataDeletions.Report(engine, this, changes);

    #endregion
}
