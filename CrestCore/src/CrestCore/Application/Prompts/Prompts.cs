using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The questions waiting on the person. An engine raises each one, and the
/// core answers a site's permission request from its Space's choices when they
/// hold one, publishing only what the person must answer. A prompt settles
/// once: the person answers it, its engine withdraws it, or its page goes. An
/// answer passes to the engine that asked and is never kept, so a credential
/// that answers a server is in no state, change or saved file. Never saved or
/// synced.
internal sealed class Prompts(Device device, Pages pages) {
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
                    new DeviceTurn(changes, now, ids, pages));
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
    public void Report(Engine engine, EngineEvent report, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        switch (report) {
            case ScriptDialogOpened opened when Raised(engine, opened.PromptId, opened.PageId, opened.Question, issue):
                changes.Publish(new ScriptDialogAsked(opened.PromptId, opened.PageId, opened.Question));
                break;
            case AuthenticationChallenged challenged when Raised(engine, challenged.PromptId, challenged.PageId, challenged.Question, issue):
                changes.Publish(new AuthenticationAsked(challenged.PromptId, challenged.PageId, challenged.Question));
                break;
            case PermissionRequested requested when Raised(engine, requested.PromptId, requested.PageId, requested.Question, issue):
                changes.Publish(new PermissionAsked(requested.PromptId, requested.PageId, requested.Question));
                break;
            case ExtensionInstallRequested requested when Raised(engine, requested.PromptId, pageId: null, requested.Question, issue):
                changes.Publish(new ExtensionInstallAsked(requested.PromptId, requested.WindowId, requested.Question));
                break;
            case PromptWithdrawn withdrawn:
                if (waiting.TryGetValue(withdrawn.PromptId, out var prompt) && ReferenceEquals(prompt.Engine, engine))
                    Settle(withdrawn.PromptId, changes);
                break;
            case ScriptDialogOpened or AuthenticationChallenged or PermissionRequested or ExtensionInstallRequested: break;
            default: throw new ArgumentOutOfRangeException(nameof(report), report.GetType().Name, "Prompts do not handle this report.");
        }
    }

    /// Answers whether a question waits on the person now. A repeated report
    /// changes nothing; a question from a page the core does not host on that
    /// engine is declined, and a permission the Space's choices answer is
    /// answered, both at once and without asking.
    private bool Raised(Engine engine, Guid promptId, Guid? pageId, object question, Action<Engine, EngineCommand> issue) {
        if (waiting.ContainsKey(promptId)) return false;
        var page = Asking(pageId);
        if (pageId is not null && (page is null || !ReferenceEquals(page.Engine, engine))) {
            issue(engine, Declining(promptId, question));
            return false;
        }
        if (question is PermissionQuestion permission && page is not null) {
            var decision = Decision(page.SpaceId, permission);
            if (decision.Verdict != SitePermissionVerdict.Ask) {
                issue(engine, new SettlePermission(promptId, decision.Grants, decision.IsPersistent));
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
