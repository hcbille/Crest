using CrestCore.Application;

namespace CrestCore.Contracts;

/// A download the engine runs, which the core records in its download ledger.
public abstract record EngineDownloadEvent(EngineDownload Download) : EngineEvent {
    #region Actions - Routing

    internal sealed override void Route(CrestApp app, Engine engine, ChangeFeed changes) =>
        app.EngineDownloads.Report(engine, this, changes, app.Issue, app.Clock.Now);

    #endregion
}
