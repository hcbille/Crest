using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

#region Types

/// What one close intent needs: where it publishes, and where it hands the
/// commands that ask pages whether they may go.
internal sealed record CloseTurn(ChangeFeed Changes, Action<Engine, EngineCommand> Issue);

#endregion

/// Prepares to close pages, windows or the app. Each page that would close and
/// that its engine holds is asked in turn whether it may go, one page at a
/// time; the first that asks to stay ends the preparation not allowed. A page
/// that goes meanwhile has nothing to ask, and one that shows another document
/// after it agreed voids the answer. Quitting with downloads in progress then
/// asks the person.
internal sealed class ClosePreparations(Pages pages, Downloads downloads, IIdSource ids) : ICloseIntentHandler<CloseTurn> {
    #region Types

    private sealed class Preparation(Guid requestId, bool quits, IEnumerable<Guid> pageIds) {
        public Guid RequestId { get; } = requestId;
        public bool Quits { get; } = quits;
        /// The pages still to ask, in order.
        public Queue<Guid> Pending { get; } = new(pageIds);
        /// Each page asked, with how many documents it had shown when asked.
        public Dictionary<Guid, long> Asked { get; } = [];
        /// The page whose answer the preparation waits for.
        public Guid? Awaiting { get; set; }
        /// The question about downloads in progress, while it waits.
        public Guid? PromptId { get; set; }
    }

    #endregion

    #region Variables

    private Preparation? underway;

    #endregion

    #region Actions - Intents

    public void Handle(CloseIntent intent, CloseTurn turn) => intent.Dispatch(this, turn);

    public void Handle(PrepareToClosePages closing, CloseTurn turn) =>
        Start(closing.RequestId, quits: false, closing.PageIds, turn.Changes, turn.Issue);

    public void Handle(PrepareToCloseWindows closing, CloseTurn turn) {
        var windows = closing.WindowIds.ToHashSet();
        Start(closing.RequestId, quits: false, pages.All.Where(page => windows.Contains(page.WindowId)).Select(page => page.Id),
            turn.Changes, turn.Issue);
    }

    public void Handle(PrepareToQuit quitting, CloseTurn turn) =>
        Start(quitting.RequestId, quits: true, pages.All.Select(page => page.Id), turn.Changes, turn.Issue);

    public void Handle(CancelClosePreparation cancellation, CloseTurn turn) {
        if (underway?.RequestId == cancellation.RequestId) Finish(allowed: false, turn.Changes);
    }

    /// The person answered whether to quit with downloads in progress.
    public void Handle(AnswerQuitWithDownloads answer, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(answer);
        ArgumentNullException.ThrowIfNull(changes);
        if (underway?.PromptId != answer.PromptId) throw new Rejected(new UnknownPrompt(answer.PromptId));
        Finish(answer.Quits, changes);
    }

    private void Start(Guid requestId, bool quits, IEnumerable<Guid> pageIds, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        if (underway is not null) throw new Rejected(new ClosePreparationUnderway(underway.RequestId));
        underway = new(requestId, quits, pageIds.Distinct().ToList());
        Advance(changes, issue);
    }

    #endregion

    #region Actions - Reports

    public void Report(Engine engine, BeforeUnloadAnswered answered, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(answered);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        if (underway?.Awaiting != answered.PageId
            || pages.Hosted(answered.PageId) is { } page && !ReferenceEquals(page.Engine, engine))
            return;
        underway.Awaiting = null;
        if (answered.Proceeds) Advance(changes, issue);
        else Finish(allowed: false, changes);
    }

    /// The page the preparation waits for went, so it has nothing to answer.
    public void Prune(ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        if (underway?.Awaiting is not { } pageId || Asking(pageId) is not null) return;
        underway.Awaiting = null;
        Advance(changes, issue);
    }

    #endregion

    #region Actions - Rules

    /// Asks the next page that may still ask, or finishes: not allowed when a
    /// page that agreed shows another document since, and for a quit with
    /// downloads in progress, once the person answers.
    private void Advance(ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        var preparation = underway!;
        while (preparation.Pending.TryDequeue(out var pageId)) {
            if (Asking(pageId) is not { } page) continue;
            preparation.Awaiting = page.Id;
            preparation.Asked[page.Id] = page.Documents;
            issue(page.Engine, new CheckBeforeUnload(page.Id));
            return;
        }
        if (preparation.Asked.Any(asked => pages.Hosted(asked.Key) is { } page && page.Documents != asked.Value)) {
            Finish(allowed: false, changes);
            return;
        }
        int live = downloads.LiveCount;
        if (preparation.Quits && live > 0) {
            preparation.PromptId = ids.Next();
            changes.Publish(new QuitWithDownloadsAsked(preparation.PromptId.Value, preparation.RequestId, live));
            return;
        }
        Finish(allowed: true, changes);
    }

    private void Finish(bool allowed, ChangeFeed changes) {
        var preparation = underway!;
        underway = null;
        if (preparation.PromptId is { } prompt) changes.Publish(new PromptSettled(prompt));
        changes.Publish(new CloseReady(preparation.RequestId, allowed));
    }

    /// A live page, which its engine can ask.
    private Page? Asking(Guid pageId) => pages.Hosted(pageId) is { } page && page.Phase == PagePhase.Live ? page : null;

    #endregion
}
