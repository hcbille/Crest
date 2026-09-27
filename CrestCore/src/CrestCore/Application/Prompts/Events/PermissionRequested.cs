using CrestCore.Application;

namespace CrestCore.Contracts;

/// A document in a page asked for a permission Crest records, which waits for
/// the core's `SettlePermission`. The core answers from the Space's choices
/// when they hold one, and asks the person only when they do not.
public sealed record PermissionRequested(Guid PromptId, Guid PageId, PermissionQuestion Question) : PromptEvent(PromptId) {
    #region Actions - Prompts

    /// A request the Space's choices answer is answered without asking.
    internal override void Apply(Prompts prompts, Engine engine, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        if (prompts.Raised(engine, PromptId, PageId, Question, new SettlePermission(PromptId, Grants: false, Remembers: false), issue,
                page => prompts.Decision(page.SpaceId, Question) is { Verdict: not SitePermissionVerdict.Ask } decision
                    ? new SettlePermission(PromptId, decision.Grants, decision.IsPersistent) : null))
            changes.Publish(new PermissionAsked(PromptId, PageId, Question));
    }

    #endregion
}
