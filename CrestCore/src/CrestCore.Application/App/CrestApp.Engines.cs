using CrestCore.Contracts;

namespace CrestCore.Application;

#region Types

/// What one engine report needs: the engine that sent it, and where what it
/// changed is published before the core announces it.
internal sealed record EngineEventTurn(Engine Engine, ChangeFeed Changes);

#endregion

public sealed partial class CrestApp : IEngineEventHandler<EngineEventTurn>, IEngineQuestionHandler<Engine> {
    #region Variables

    /// The engine bindings pages open on.
    private readonly Engines engines = new();

    /// Commands issued and not yet delivered, oldest first.
    private readonly Queue<(Engine Engine, EngineCommand Command)> undelivered = [];
    private readonly Lock deliveryGate = new();

    /// A call is handing commands to bindings. Any other call, on this thread
    /// inside a binding or on another, only adds to the queue.
    private bool delivering;

    /// The engines as the core last published them.
    private EngineRoster publishedEngines = EngineRoster.Unregistered;

    #endregion

    #region Actions - Engines

    /// Registers an engine binding. The core hands it commands through `run`,
    /// in the order it issued them, never while it holds a lock. Throws
    /// `Rejected` when the engine lacks a required capability, is already
    /// registered, or asks to be the default beside another default.
    public Engine RegisterEngine(EngineRegistration registration, Action<EngineCommand> run) {
        Engine engine;
        lock (gate) {
            engine = engines.Register(registration, run);
            PublishEngines(Announce);
        }
        WakeIfOwed();
        return engine;
    }

    /// Removes a binding. Commands still waiting for it are dropped.
    public void UnregisterEngine(Engine engine) {
        lock (gate) {
            engines.Unregister(engine);
            PublishEngines(Announce);
        }
        WakeIfOwed();
    }

    /// The engines as they stand, and what they offer with the pages open now.
    /// The caller holds the lock.
    private EngineRoster RegisteredEngines() => engines.Roster(pages.HostingEngines);

    /// Hands `publish` the engines when they changed since the core last
    /// published them: one registered or went away, or what they offer
    /// changed because a page opened on an engine no page used or an engine's
    /// last page went. The shortcut bindings follow when the commands they
    /// offer changed. The caller holds the lock.
    private void PublishEngines(Action<Change> publish) {
        var current = RegisteredEngines();
        if (current.SameAs(publishedEngines)) return;
        var before = Engines.OfferedCommands(publishedEngines);
        publishedEngines = current;
        publish(new EnginesChanged(current));
        if (device.ShortcutsAfter(before, Engines.OfferedCommands(current)) is { } changed) publish(changed);
    }

    /// Applies what an engine saw happen to one of its pages. A report is
    /// never refused; one about a page the core no longer knows changes
    /// nothing. What it changed arrives through the next drain, and commands
    /// it caused, such as bringing back a page whose renderer stopped, are
    /// delivered after it, never on its stack when it arrives inside a
    /// delivery.
    public void Report(Engine engine, EngineEvent report) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(report);
        var changes = new ChangeFeed();
        lock (gate) report.Dispatch(this, new EngineEventTurn(engine, changes));
        foreach (var change in changes.Published) Announce(change);
        WakeIfOwed();
        WakeForRequestedTurn();
        Deliver();
    }

    // Each report goes to the area it is about. The caller holds the lock.

    void IEngineEventHandler<EngineEventTurn>.Handle(PageEvent report, EngineEventTurn turn) {
        pages.Report(turn.Engine, report, turn.Changes, Issue);
        AfterPageReport(turn.Changes);
    }

    void IEngineEventHandler<EngineEventTurn>.Handle(PageOffered offer, EngineEventTurn turn) {
        pages.Report(turn.Engine, offer, turn.Changes, Issue);
        AfterPageReport(turn.Changes);
    }

    void IEngineEventHandler<EngineEventTurn>.Handle(PromptEvent report, EngineEventTurn turn) => prompts.Report(turn.Engine, report, turn.Changes, Issue);

    void IEngineEventHandler<EngineEventTurn>.Handle(EngineDownloadEvent report, EngineEventTurn turn) =>
        engineDownloads.Report(turn.Engine, report, turn.Changes, Issue, clock.Now);

    void IEngineEventHandler<EngineEventTurn>.Handle(BeforeUnloadAnswered answered, EngineEventTurn turn) =>
        closePreparations.Report(turn.Engine, answered, turn.Changes, Issue);

    void IEngineEventHandler<EngineEventTurn>.Handle(DataErased erased, EngineEventTurn turn) => dataDeletions.Report(turn.Engine, erased, turn.Changes);

    /// A report that moved a page to another engine, or offered one that may
    /// be the first a registered engine hosts, changes what the engines offer,
    /// and what a page that went had asked no longer waits.
    private void AfterPageReport(ChangeFeed changes) {
        PublishEngines(changes.Publish);
        prompts.Prune(changes);
        closePreparations.Prune(changes, Issue);
    }

    /// Answers what an engine asks about one of its pages while the engine
    /// waits, from the state as it stands, changing nothing.
    public TAnswer Ask<TAnswer>(Engine engine, EngineQuestion<TAnswer> question) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(question);
        lock (gate) return question.Dispatch(this, engine);
    }

    /// A question about a page the core does not host on that engine leaves
    /// the page to the engine: its link loads in the page.
    LinkNavigationAnswer IEngineQuestionHandler<Engine>.Handle(LinkActivation activation, Engine engine) =>
        ReferenceEquals(pages.Hosted(activation.PageId)?.Engine, engine)
            ? device.Answer(new LinkNavigation(activation.PageId, activation.Url, activation.Gesture), pages)
            : new LinkNavigationAnswer(LinkNavigationDecision.Navigate);

    #endregion

    #region Actions - Delivery

    /// Queues a command for delivery once the core lets go of its lock.
    private void Issue(Engine engine, EngineCommand command) {
        lock (deliveryGate) undelivered.Enqueue((engine, command));
    }

    /// Hands every queued command to its binding, oldest first, unless a
    /// delivery is already under way: that one delivers what was added. A
    /// binding that sends an intent or a report while it runs a command adds to
    /// the queue, and the queue is never entered twice.
    private void Deliver() {
        lock (deliveryGate) {
            if (delivering) return;
            delivering = true;
        }
        while (true) {
            (Engine Engine, EngineCommand Command) next;
            lock (deliveryGate) {
                if (!undelivered.TryDequeue(out next)) {
                    delivering = false;
                    return;
                }
            }
            try {
                next.Engine.Run(next.Command);
            } catch {
                lock (deliveryGate) delivering = false;
                throw;
            }
        }
    }

    #endregion
}
