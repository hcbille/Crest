using CrestCore.Application;

namespace CrestCore.Contracts;

/// Whether a page the core asked may go.
public sealed record BeforeUnloadAnswered(Guid PageId, bool Proceeds) : EngineEvent {
    #region Actions - Routing

    internal override void Route(CrestApp app, Engine engine, ChangeFeed changes) =>
        app.ClosePreparations.Report(engine, this, changes, app.Issue);

    #endregion
}
