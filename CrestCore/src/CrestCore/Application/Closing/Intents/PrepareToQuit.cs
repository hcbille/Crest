using CrestCore.Application;

namespace CrestCore.Contracts;

/// Prepares to quit: every page this device hosts may go, and the person
/// agrees to stop the downloads still in progress.
public sealed record PrepareToQuit(Guid RequestId) : CloseIntent(RequestId) {
    #region Actions - Closing

    internal override void Apply(ClosePreparations preparations, ChangeFeed changes, Action<Engine, EngineCommand> issue) =>
        preparations.Start(RequestId, quits: true, preparations.Pages.All.Select(page => page.Id), changes, issue);

    #endregion
}
