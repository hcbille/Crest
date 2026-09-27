using CrestCore.Contracts;

namespace CrestCore.Application;

public sealed partial class CrestApp {
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
        lock (gate) {
            if (Prompts.Concerns(report)) {
                prompts.Report(engine, report, changes, Issue);
            } else if (EngineDownloads.Concerns(report)) {
                engineDownloads.Report(engine, report, changes, Issue, clock.Now);
            } else if (ClosePreparations.Concerns(report)) {
                closePreparations.Report(engine, report, changes, Issue);
            } else if (DataDeletions.Concerns(report)) {
                dataDeletions.Report(engine, report, changes);
            } else {
                // Every other report is about pages.
                var turn = new PageTurn(changes, Issue);
                if (report is PageEvent pageReport) pages.Report(pageReport, engine, turn);
                else if (report is PageOffered offer) offer.Apply(pages, engine, turn);
                else throw new ArgumentOutOfRangeException(nameof(report), report.GetType().Name, "No area handles this report.");
                // A report that moved a page to another engine, or offered one
                // that may be the first a registered engine hosts, changes what
                // the engines offer.
                PublishEngines(changes.Publish);
                prompts.Prune(changes);
                closePreparations.Prune(changes, Issue);
            }
        }
        foreach (var change in changes.Published) Announce(change);
        WakeIfOwed();
        WakeForRequestedTurn();
        Deliver();
    }

    /// Answers what an engine asks about one of its pages while the engine
    /// waits, from the state as it stands, changing nothing. A question about
    /// a page the core does not host on that engine leaves the page to the
    /// engine: its link loads in the page.
    public TAnswer Ask<TAnswer>(Engine engine, EngineQuestion<TAnswer> question) {
        ArgumentNullException.ThrowIfNull(engine);
        ArgumentNullException.ThrowIfNull(question);
        lock (gate) {
            object answer = question switch {
                LinkActivation activation => ReferenceEquals(pages.Hosted(activation.PageId)?.Engine, engine)
                    ? device.Answer(new LinkNavigation(activation.PageId, activation.Url, activation.Gesture), pages)
                    : new LinkNavigationAnswer(LinkNavigationDecision.Navigate),
                _ => throw new ArgumentOutOfRangeException(nameof(question), question.GetType().Name, "No area answers this question.")
            };
            return (TAnswer)answer;
        }
    }

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
