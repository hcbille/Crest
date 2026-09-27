using CrestCore.Application;

namespace CrestCore.Contracts;

/// An answer to a question waiting on the person. A prompt lasts until the
/// person answers it, its engine withdraws it or its page goes, and is never
/// saved or synced.
public abstract record PromptIntent(Guid PromptId) : Intent {
    #region Actions - Routing

    internal sealed override IReadOnlyList<Change> Route(CrestApp app) => app.Turn(changes => {
        if (ClosePreparations.Concerns(this)) app.ClosePreparations.Handle(this, changes);
        else if (EngineDownloads.Concerns(this)) app.EngineDownloads.Handle(this, changes, app.Issue);
        else app.Prompts.Handle(this, changes, app.Issue, app.Clock.Now, app.Ids);
    });

    #endregion
}
