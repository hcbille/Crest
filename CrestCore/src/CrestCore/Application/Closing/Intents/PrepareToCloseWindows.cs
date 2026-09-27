using CrestCore.Application;

namespace CrestCore.Contracts;

/// Prepares to close the windows `WindowIds` names, with every page they host.
public sealed record PrepareToCloseWindows(Guid RequestId, IReadOnlyList<Guid> WindowIds) : CloseIntent(RequestId) {
    #region Actions - Closing

    internal override void Apply(ClosePreparations preparations, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        var windows = WindowIds.ToHashSet();
        var pages = preparations.Pages.All.Where(page => windows.Contains(page.WindowId)).Select(page => page.Id);
        preparations.Start(RequestId, quits: false, pages, changes, issue);
    }

    #endregion
}
