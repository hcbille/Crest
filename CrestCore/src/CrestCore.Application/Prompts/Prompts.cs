using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

#region Types

/// What one prompt report needs: the engine that raised or withdrew the
/// question, where the report publishes, and where it hands the command that
/// answers the engine at once.
internal sealed record PromptEventTurn(Engine Engine, ChangeFeed Changes, Action<Engine, EngineCommand> Issue);

#endregion

/// The questions waiting on the person. An engine raises each one, and the
/// core answers a site's permission request from its Space's choices when they
/// hold one, publishing only what the person must answer. A prompt settles
/// once: the person answers it, its engine withdraws it, or its page goes. An
/// answer passes to the engine that asked and is never kept, so a credential
/// that answers a server is in no state, change or saved file. Never saved or
/// synced.
internal sealed class Prompts(Device device, Pages pages) : IPromptEventHandler<PromptEventTurn> {
    #region Types

    /// A prompt waiting on the person: the engine that asked it, the page that
    /// asked or none for one the engine asks itself, and the question, which
    /// says what kind of answer it takes.
    private sealed record Waiting(Engine Engine, Guid? PageId, object Question);

    #endregion

    #region Variables

    private readonly Dictionary<Guid, Waiting> waiting = [];

    #endregion

    #region Actions - Intents

    /// Runs one answer, publishing what it changed to `changes` and handing the
    /// answer to `issue` for the engine that asked. A permission the person
    /// answers to remember becomes the Space's choice in the same step, unless
    /// the Space locked while the prompt waited. A block the Space took while
    /// the prompt waited outranks the answer, which then records nothing.
    public void Handle(PromptIntent intent, ChangeFeed changes, Action<Engine, EngineCommand> issue, DateTimeOffset now,
        IIdSource ids) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        ArgumentNullException.ThrowIfNull(ids);
        if (!waiting.TryGetValue(intent.PromptId, out var prompt)) throw new Rejected(new UnknownPrompt(intent.PromptId));
        EngineCommand settlement = (prompt.Question, intent) switch {
            (ScriptDialogQuestion, AnswerScriptDialog answer) => new SettleScriptDialog(answer.PromptId, answer.Accepted, answer.Text),
            (AuthenticationQuestion, AnswerAuthentication answer) => new SettleAuthentication(answer.PromptId, answer.Credential),
            (PermissionQuestion, AnswerPermission answer) => new SettlePermission(answer.PromptId, answer.Grants, answer.Remembers),
            (ExtensionInstallQuestion, AnswerExtensionInstall answer) =>
                new SettleExtensionInstall(answer.PromptId, answer.Accepted, answer.WithholdsSiteAccess),
            _ => throw new Rejected(new PromptAnswerMismatch(intent.PromptId))
        };
        if (prompt.Question is PermissionQuestion asked && Asking(prompt.PageId) is { } asking
            && Decision(asking.SpaceId, asked) is { Denies: true } blocked) {
            Settle(intent.PromptId, changes);
            issue(prompt.Engine, new SettlePermission(intent.PromptId, Grants: false, blocked.IsPersistent));
            return;
        }
        if (prompt.Question is PermissionQuestion permission && intent is AnswerPermission { Remembers: true } chosen
            && Asking(prompt.PageId) is { } page && permission.Origin.IsValid) {
            var decision = chosen.Grants ? SitePermissionDecision.GrantPersistently : SitePermissionDecision.DenyPersistently;
            try {
                device.Handle(new DecideSitePermission(page.SpaceId, permission.Origin, permission.Permission, Detail: null, decision),
                    new SitePermissionTurn(changes, now, ids));
            } catch (Rejected) {
                // A Space that locked keeps nothing; the request is still answered.
            }
        }
        Settle(intent.PromptId, changes);
        issue(prompt.Engine, settlement);
    }

    #endregion

    #region Actions - Reports

    /// Applies an engine's prompt report. A question from a page the core does
    /// not host on that engine is declined at once, and a permission request
    /// the Space's choices answer is answered without asking.
    public void Report(Engine engine, PromptEvent report, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        report.Dispatch(this, new PromptEventTurn(engine, changes, issue));
    }

    public void Handle(ScriptDialogOpened opened, PromptEventTurn turn) {
        if (Raised(turn, opened.PromptId, opened.PageId, opened.Question))
            turn.Changes.Publish(new ScriptDialogAsked(opened.PromptId, opened.PageId, opened.Question));
    }

    public void Handle(AuthenticationChallenged challenged, PromptEventTurn turn) {
        if (Raised(turn, challenged.PromptId, challenged.PageId, challenged.Question))
            turn.Changes.Publish(new AuthenticationAsked(challenged.PromptId, challenged.PageId, challenged.Question));
    }

    public void Handle(PermissionRequested requested, PromptEventTurn turn) {
        if (Raised(turn, requested.PromptId, requested.PageId, requested.Question))
            turn.Changes.Publish(new PermissionAsked(requested.PromptId, requested.PageId, requested.Question));
    }

    public void Handle(ExtensionInstallRequested requested, PromptEventTurn turn) {
        if (Raised(turn, requested.PromptId, pageId: null, requested.Question))
            turn.Changes.Publish(new ExtensionInstallAsked(requested.PromptId, requested.WindowId, requested.Question));
    }

    public void Handle(PromptWithdrawn withdrawn, PromptEventTurn turn) {
        if (waiting.TryGetValue(withdrawn.PromptId, out var prompt) && ReferenceEquals(prompt.Engine, turn.Engine))
            Settle(withdrawn.PromptId, turn.Changes);
    }

    /// Answers whether a question waits on the person now. A repeated report
    /// changes nothing; a question from a page the core does not host on that
    /// engine is declined, and a permission the Space's choices answer is
    /// answered, both at once and without asking.
    private bool Raised(PromptEventTurn turn, Guid promptId, Guid? pageId, object question) {
        var engine = turn.Engine;
        if (waiting.ContainsKey(promptId)) return false;
        var page = Asking(pageId);
        if (pageId is not null && (page is null || !ReferenceEquals(page.Engine, engine))) {
            turn.Issue(engine, Declining(promptId, question));
            return false;
        }
        if (question is PermissionQuestion permission && page is not null) {
            var decision = Decision(page.SpaceId, permission);
            if (decision.Verdict != SitePermissionVerdict.Ask) {
                turn.Issue(engine, new SettlePermission(promptId, decision.Grants, decision.IsPersistent));
                return false;
            }
        }
        waiting[promptId] = new(engine, pageId, question);
        return true;
    }

    #endregion

    #region Actions - Pages

    /// Settles each prompt whose page is gone, no longer holds its engine
    /// page, or moved to another engine. The engine that asked closes that
    /// page and what it asked with it, so it hears nothing.
    public void Prune(ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(changes);
        foreach (var (id, prompt) in waiting.ToArray())
            if (prompt.PageId is not null && (Asking(prompt.PageId) is not { } page || !ReferenceEquals(page.Engine, prompt.Engine)))
                Settle(id, changes);
    }

    #endregion

    #region Actions - Rules

    private void Settle(Guid promptId, ChangeFeed changes) {
        if (waiting.Remove(promptId)) changes.Publish(new PromptSettled(promptId));
    }

    /// What Space `spaceId`'s choices say about `permission`. A capture request
    /// respects a block on either device it asks for, and a combined grant
    /// answers for each device.
    private SitePermissionDecision Decision(Guid spaceId, PermissionQuestion permission) =>
        (permission.Permission.IsMedia
            ? device.Answer(new CaptureDecision(spaceId, permission.Origin, permission.Permission))
            : device.Answer(new SiteDecision(spaceId, permission.Origin, permission.Permission, Detail: null))).Decision;

    /// The page `pageId` names while the core hosts it and its engine still
    /// holds it, so it may ask; null for none.
    private Page? Asking(Guid? pageId) =>
        pageId is { } id && pages.Hosted(id) is { Phase.HoldsEnginePage: true } page ? page : null;

    /// The command that declines `question`: nothing accepted, granted or given.
    private static EngineCommand Declining(Guid promptId, object question) => question switch {
        ScriptDialogQuestion => new SettleScriptDialog(promptId, Accepted: false, Text: null),
        AuthenticationQuestion => new SettleAuthentication(promptId, Credential: null),
        PermissionQuestion => new SettlePermission(promptId, Grants: false, Remembers: false),
        ExtensionInstallQuestion => new SettleExtensionInstall(promptId, Accepted: false, WithholdsSiteAccess: false),
        _ => throw new ArgumentOutOfRangeException(nameof(question), question.GetType().Name, "No answer declines this question.")
    };

    #endregion
}
