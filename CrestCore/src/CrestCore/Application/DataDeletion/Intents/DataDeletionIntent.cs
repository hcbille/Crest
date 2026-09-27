using CrestCore.Application;

namespace CrestCore.Contracts;

/// A request to erase what the engines keep for a profile, which the core asks
/// of every registered engine, started or not. It ends with `DataDeleted`.
public abstract record DataDeletionIntent(Guid RequestId) : Intent {
    #region Actions - Routing

    internal sealed override IReadOnlyList<Change> Route(CrestApp app) =>
        app.Turn(changes => app.DataDeletions.Handle(this, changes, app.Issue));

    #endregion
}
