using CrestCore.Application;

namespace CrestCore.Contracts;

/// A request to close pages, windows or the app, which the core prepares by
/// asking each page it would close whether it may go. One preparation runs at
/// a time, and ends with `CloseReady`.
public abstract record CloseIntent(Guid RequestId) : Intent {
    #region Actions - Routing

    internal sealed override IReadOnlyList<Change> Route(CrestApp app) =>
        app.Turn(changes => app.ClosePreparations.Handle(this, changes, app.Issue));

    #endregion
}
