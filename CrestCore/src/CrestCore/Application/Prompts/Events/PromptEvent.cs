using CrestCore.Application;

namespace CrestCore.Contracts;

/// A question the engine raises with the person, or takes back, which its
/// `PromptId` names until the core settles it.
public abstract record PromptEvent(Guid PromptId) : EngineEvent {
    #region Actions - Routing

    internal sealed override void Route(CrestApp app, Engine engine, ChangeFeed changes) =>
        app.Prompts.Report(engine, this, changes, app.Issue);

    #endregion
}
