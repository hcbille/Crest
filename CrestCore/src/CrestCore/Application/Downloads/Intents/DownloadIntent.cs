using CrestCore.Application;

namespace CrestCore.Contracts;

/// An intent the downloads ledger handles.
public abstract record DownloadIntent : Intent {
    #region Actions - Routing

    /// An engine's download settles on the engine first, then the ledger
    /// records it.
    internal sealed override IReadOnlyList<Change> Route(CrestApp app) => app.Turn(changes => {
        app.EngineDownloads.Before(this, changes, app.Issue);
        app.Downloads.Handle(this, changes);
    });

    #endregion
}
