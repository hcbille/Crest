using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Prepares to close pages, windows or the app. Each page that would close and
/// that its engine holds is asked in turn whether it may go, one page at a
/// time; the first that asks to stay ends the preparation not allowed. A page
/// that goes meanwhile has nothing to ask, and one that shows another document
/// after it agreed voids the answer. Quitting with downloads in progress then
/// asks the person. TRANSITIONAL: nothing calls it until the platform's close
/// and quit wiring moves here.
internal sealed class ClosePreparations(Pages pages, Downloads downloads, IIdSource ids) {
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

    public void Handle(CloseIntent intent, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        switch (intent) {
            case PrepareToClosePages closing: Start(closing.RequestId, quits: false, closing.PageIds, changes, issue); break;
            case PrepareToCloseWindows closing:
                var windows = closing.WindowIds.ToHashSet();
                Start(closing.RequestId, quits: false, pages.All.Where(page => windows.Contains(page.WindowId)).Select(page => page.Id),
                    changes, issue);
                break;
            case PrepareToQuit quitting: Start(quitting.RequestId, quits: true, pages.All.Select(page => page.Id), changes, issue); break;
            case CancelClosePreparation cancellation:
                if (underway?.RequestId == cancellation.RequestId) Finish(allowed: false, changes);
                break;
            default: throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "Close preparations do not handle this intent.");
        }
    }

    /// Whether the answer is to the question about downloads in progress.
    public static bool Concerns(PromptIntent intent) => intent is AnswerQuitWithDownloads;

    /// The person answered whether to quit with downloads in progress.
    public void Handle(PromptIntent intent, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(changes);
        if (intent is not AnswerQuitWithDownloads answer || underway?.PromptId != answer.PromptId)
            throw new Rejected(new UnknownPrompt(intent.PromptId));
        Finish(answer.Quits, changes);
    }

    private void Start(Guid requestId, bool quits, IEnumerable<Guid> pageIds, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        if (underway is not null) throw new Rejected(new ClosePreparationUnderway(underway.RequestId));
        underway = new(requestId, quits, pageIds.Distinct().ToList());
        Advance(changes, issue);
    }

    #endregion

    #region Actions - Reports

    /// Whether the report answers a close preparation.
    public static bool Concerns(EngineEvent report) => report is BeforeUnloadAnswered;

    public void Report(Engine engine, EngineEvent report, ChangeFeed changes, Action<Engine, EngineCommand> issue) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(changes);
        ArgumentNullException.ThrowIfNull(issue);
        if (report is not BeforeUnloadAnswered answered || underway?.Awaiting != answered.PageId
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
