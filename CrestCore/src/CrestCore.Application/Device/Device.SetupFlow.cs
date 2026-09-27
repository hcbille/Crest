using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

#region Types

/// What one setup flow intent needs: where it publishes the flow it leaves,
/// where new identities come from, and the app's own finish, which applies
/// the manual setup through the workspace.
internal sealed record SetupFlowTurn(ChangeFeed Changes, IIdSource Ids, Action<FinishSetup> Finish);

#endregion

/// Setup on this device: the flow the person is in, over one workspace, and
/// whether this device has completed setup, which the device store keeps. The
/// flow holds the browsers chosen to import from, the queue of them and the
/// review of the one it is on; the platform reads each browser and imports its
/// passwords, and tells the flow how that went. `FinishSetup` applies the
/// manual setup and completes setup; see `CrestApp`.
internal sealed partial class Device : ISetupFlowIntentHandler<SetupFlowTurn> {
    #region Types

    /// What finishing setup over `WorkspaceId` does: apply the manual setup the
    /// device holds, and open the Getting Started guide.
    public sealed record SetupFinish(Guid WorkspaceId, bool AppliesManualSetup, bool OpensGuide, int CreatedSpaces);

    #endregion

    #region Variables

    /// Setup as the person sees it, or null while it is not open.
    private SetupFlowState? setupFlow;
    /// Whether this device has completed setup.
    private bool setupCompleted;

    #endregion

    #region Actions - Setup flow intents

    /// Runs one setup flow intent, publishing the flow it leaves.
    public void Handle(SetupFlowIntent intent, SetupFlowTurn turn) => intent.Dispatch(this, turn);

    public void Handle(AdoptSetupCompletion adoption, SetupFlowTurn turn) {
        lock (gate) Adopt(adoption, turn.Changes);
    }

    /// Opens setup for `intent`'s entry over its workspace. A manual setup the
    /// device holds is kept for the manual-setup step only where the platform
    /// keeps one and the entry does not start it over.
    public void Handle(StartSetup intent, SetupFlowTurn turn) {
        var authority = Workspace(intent.WorkspaceId);
        if (!authority.Kind.KeepsAppPreferences) throw new Rejected(new PersistentWorkspaceRequired(intent.WorkspaceId));
        var session = authority.Current;
        lock (gate) {
            if (intent.Entry.StartsManualSetupOver || !platform.KeepsSetupDraft) KeepSetup(null, turn.Changes);
            var flow = new SetupFlowState(intent.WorkspaceId, intent.Entry, intent.Entry.FirstStep, BackStep: null, NextStep: null,
                SetupPhase.Idle, Offered: setupFlow?.Offered ?? [], Selected: [], Queue: null, Source: null, Review: null, Failure: null,
                Summary: null, OpensGuide: false, OpensCrestFromWelcome: false);
            if (flow.Step == SetupStep.ManualSetup) BeginSetup(intent.WorkspaceId, session, startsOver: false, turn.Changes, turn.Ids);
            Publish(flow, turn.Changes);
        }
    }

    /// The app finishes setup, which applies the manual setup through the
    /// workspace before the device completes it.
    public void Handle(FinishSetup finish, SetupFlowTurn turn) => turn.Finish(finish);

    public void Handle(ShowSetupStep show, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Showing(flow, show.Step, session, turn.Changes, turn.Ids));

    public void Handle(OfferImportSources offer, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, _) => flow with { Offered = offer.Installed, Selected = [.. offer.Installed.Where(flow.Selected.Contains)] });

    public void Handle(ToggleImportSource toggle, SetupFlowTurn turn) => ReviseFlow(turn, (flow, _) => Toggling(Idle(flow), toggle.Source));

    public void Handle(ContinueImport continuing, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Continuing(Idle(flow), session, turn.Changes, turn.Ids));

    public void Handle(ReviewImport review, SetupFlowTurn turn) => ReviseFlow(turn, (flow, session) => Reviewing(flow, review, session));

    public void Handle(FailImport failure, SetupFlowTurn turn) => ReviseFlow(turn, (flow, _) => Failing(flow, failure));

    public void Handle(CancelImportRead cancel, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, _) => flow.Phase == SetupPhase.Reading
            ? flow with { Phase = SetupPhase.Idle, Step = SetupStep.ImportBrowser, Source = null, Failure = null } : flow);

    public void Handle(ChooseImportDestination choice, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Editing(flow, review =>
            ImportReviewPolicy.ChoosingDestination(review, choice.SourceSpaceId, choice.DestinationSpaceId, session)));

    public void Handle(IncludeImportTabs tabs, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Editing(flow, review =>
            ImportReviewPolicy.IncludingTabs(review, tabs.SourceSpaceId, tabs.TabIds, tabs.Included, session)));

    public void Handle(PlaceImportTab placing, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Editing(flow, review =>
            ImportReviewPolicy.Placing(review, placing.SourceSpaceId, placing.TabId, placing.Placement, session)));

    public void Handle(IncludeImportSpace space, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Editing(flow, review =>
            ImportReviewPolicy.IncludingSpace(review, space.SourceSpaceId, space.Included, session)));

    public void Handle(IncludeImportPasswords passwords, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Editing(flow, review =>
            ImportReviewPolicy.IncludingPasswords(review, passwords.SourceSpaceId, passwords.Included, session)));

    public void Handle(CustomizeImportSpace customizing, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Editing(flow, review =>
            ImportReviewPolicy.Customizing(review, customizing.SourceSpaceId, customizing.Customization, session)));

    public void Handle(ShowImportSpace shown, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, _) => flow.Review is { } review
            ? flow with { Review = ImportReviewPolicy.Showing(review, shown.SourceSpaceId) } : flow);

    public void Handle(BeginImportCommit begin, SetupFlowTurn turn) => ReviseFlow(turn, (flow, _) => Committing(flow));

    public void Handle(FinishImportCommit finished, SetupFlowTurn turn) =>
        ReviseFlow(turn, (flow, session) => Committed(flow, finished.PasswordCount, session, turn.Changes, turn.Ids));

    /// Publishes the flow `edit` makes of the open one over the session setup
    /// works over, which is read outside the device lock. Throws `Rejected`
    /// with `NoSetup` while no setup is open.
    private void ReviseFlow(SetupFlowTurn turn, Func<SetupFlowState, SessionState, SetupFlowState> edit) {
        var session = FlowSession();
        lock (gate) Publish(edit(setupFlow ?? throw new Rejected(new NoSetup()), session), turn.Changes);
    }

    /// The session setup works over, read outside the device lock.
    private SessionState FlowSession() {
        Guid workspaceId;
        lock (gate) workspaceId = (setupFlow ?? throw new Rejected(new NoSetup())).WorkspaceId;
        return (Attached(workspaceId) ?? throw new Rejected(new NoSetup())).Current;
    }

    #endregion

    #region Actions - Steps

    /// `flow` on `step`. The review needs a review; the manual-setup step
    /// starts the manual setup or goes on with it. The caller holds the device lock.
    private SetupFlowState Showing(SetupFlowState flow, SetupStep step, SessionState session, ChangeFeed changes, IIdSource ids) {
        var idle = Idle(flow);
        if (step == SetupStep.Review && flow.Review is null) return flow;
        if (step == SetupStep.ManualSetup) BeginSetup(flow.WorkspaceId, session, startsOver: false, changes, ids);
        return idle with { Step = step, Phase = step == SetupStep.Review ? SetupPhase.Reviewing : SetupPhase.Idle };
    }

    /// `flow` when it is not reading or importing. Throws `Rejected` with
    /// `SetupBusy` otherwise.
    private static SetupFlowState Idle(SetupFlowState flow) => flow.Phase.IsBusy ? throw new Rejected(new SetupBusy()) : flow;

    /// `flow` with `source` chosen or left out. Any review or failure goes, and
    /// the queue starts over from the chosen browsers.
    private static SetupFlowState Toggling(SetupFlowState flow, ImportSource source) {
        var selected = flow.Selected.Contains(source) ? flow.Selected.Where(chosen => chosen != source) : flow.Selected.Append(source);
        var chosen = selected.ToHashSet();
        return flow with {
            Step = SetupStep.ImportBrowser,
            Phase = SetupPhase.Idle,
            Selected = [.. chosen.OrderBy(Position(flow))],
            Queue = new([.. flow.Offered.Where(chosen.Contains)], 0),
            Source = null,
            Review = null,
            Failure = null
        };
    }

    /// Where `source` stands among the browsers `flow` offers.
    private static Func<ImportSource, int> Position(SetupFlowState flow) => source => {
        int index = flow.Offered.ToList().IndexOf(source);
        return index < 0 ? int.MaxValue : index;
    };

    /// `flow` going on from choosing browsers: to the manual setup when none is
    /// chosen, or to reading the next chosen one. The caller holds the device lock.
    private SetupFlowState Continuing(SetupFlowState flow, SessionState session, ChangeFeed changes, IIdSource ids) {
        if (flow.Selected.Count == 0) {
            BeginSetup(flow.WorkspaceId, session, startsOver: false, changes, ids);
            return flow with { Step = SetupStep.ManualSetup, Phase = SetupPhase.Idle, Source = null, Failure = null };
        }
        var queue = flow.Queue is { Current: not null } current && current.Sources.Skip(current.Index).ToHashSet().SetEquals(flow.Selected)
            ? current : new SetupImportQueue([.. flow.Offered.Where(flow.Selected.Contains)], 0);
        if (queue.Current is not { } source)
            return flow with {
                Queue = queue,
                Step = SetupStep.ImportBrowser,
                Phase = SetupPhase.Idle,
                Failure = new(SetupFailureReason.SourceUnavailable, null, null)
            };
        return flow with { Queue = queue, Step = SetupStep.ImportBrowser, Phase = SetupPhase.Reading, Source = source, Failure = null };
    }

    #endregion

    #region Actions - Reviews

    /// `flow` reviewing the Spaces `intent` brings from the browser it reads.
    /// A read it no longer waits for changes nothing. Throws `Rejected` with
    /// `InvalidImport` for Spaces that repeat an identity or hold a split
    /// repair would rewrite, or `SpaceLimitReached` for more than a workspace
    /// holds.
    private static SetupFlowState Reviewing(SetupFlowState flow, ReviewImport intent, SessionState session) {
        if (flow.Phase != SetupPhase.Reading || flow.Source != intent.Source) return flow;
        if (intent.Spaces.Select(space => space.Id).Distinct().Count() != intent.Spaces.Count)
            throw new Rejected(new InvalidImport(ImportFlaw.UnpairedChoices));
        WorkspaceImportPolicy.RequireSpaceCapacity(0, intent.Spaces.Count);
        foreach (var space in intent.Spaces)
            WorkspaceImportPolicy.RequireSplitMembership([.. space.Tabs.Select(tab => new SplitMember(tab.SplitGroupId, tab.Placement, tab.FolderId))]);
        return flow with {
            Step = SetupStep.Review,
            Phase = SetupPhase.Reviewing,
            Review = ImportReviewPolicy.Started(intent.Source, intent.Spaces,
                ImportPasswordRouting.Counts(intent.Source, intent.Passwords, intent.Spaces), session),
            Failure = null
        };
    }

    /// `flow` with its review edited by `edit`, while it is not importing.
    private static SetupFlowState Editing(SetupFlowState flow, Func<SetupImportReview, SetupImportReview> edit) {
        var idle = Idle(flow);
        return idle.Review is { } review ? idle with { Review = edit(review) } : idle;
    }

    /// `flow` after reading or importing failed for `intent`'s reason, back
    /// where the person can try again.
    private static SetupFlowState Failing(SetupFlowState flow, FailImport intent) {
        var failure = new SetupFailure(intent.Reason, intent.Source, intent.Detail);
        return intent.Reason.ReturnsToReview && flow.Review is not null
            ? flow with { Step = SetupStep.Review, Phase = SetupPhase.Reviewing, Failure = failure }
            : flow with { Step = SetupStep.ImportBrowser, Phase = SetupPhase.Idle, Source = null, Failure = failure };
    }

    /// `flow` importing its review. Throws `Rejected` with `NoIncludedSpaces`
    /// for a review that brings no Space.
    private static SetupFlowState Committing(SetupFlowState flow) {
        var idle = Idle(flow);
        if (idle.Review is not { } review) throw new Rejected(new NoSetup());
        if (!review.HasIncludedSpaces) throw new Rejected(new NoIncludedSpaces());
        return idle with { Phase = SetupPhase.Committing, Failure = null };
    }

    /// `flow` once its review is imported with `passwordCount` passwords: on
    /// to the next chosen browser, or after the last to the manual setup when
    /// setup walks the person through Crest, or else to what it did. The
    /// caller holds the device lock.
    private SetupFlowState Committed(SetupFlowState flow, int passwordCount, SessionState session, ChangeFeed changes, IIdSource ids) {
        if (flow.Phase != SetupPhase.Committing || flow.Review is not { } review) return flow;
        var summary = new SetupSummary(IsImport: true, review.IncludedTabCount, Math.Max(passwordCount, 0),
            review.Spaces.Count(space => space.Included));
        var queue = flow.Queue is { } current ? current with { Index = current.Index + 1 } : null;
        var done = flow with {
            Phase = SetupPhase.Idle,
            Selected = [.. flow.Selected.Where(source => source != review.Source)],
            Queue = queue,
            Source = null,
            Review = null,
            Failure = null,
            Summary = summary
        };
        if (queue?.Current is { } next) return done with { Step = SetupStep.ImportBrowser, Phase = SetupPhase.Reading, Source = next };
        if (!flow.Entry.IsGuided) return done with { Step = SetupStep.Complete };
        BeginSetup(flow.WorkspaceId, session, startsOver: false, changes, ids);
        return done with { Step = SetupStep.ManualSetup };
    }

    /// The review setup holds for `workspaceId`, which `ImportReviewedSpaces`
    /// imports, or null when there is none.
    public SetupImportReview? ImportReview(Guid workspaceId) {
        lock (gate) return setupFlow is { } flow && flow.WorkspaceId == workspaceId ? flow.Review : null;
    }

    /// Where each of the query's passwords goes once the review setup holds
    /// for its workspace is imported, leaving out Spaces that are gone or
    /// locked. Throws `Rejected` with `NoSetup` when setup holds no review for
    /// the workspace.
    public ImportPasswordRoutes Answer(ImportPasswordDestinations query) {
        ArgumentNullException.ThrowIfNull(query);
        var review = ImportReview(query.WorkspaceId) ?? throw new Rejected(new NoSetup());
        var authority = Workspace(query.WorkspaceId);
        return ImportPasswordRouting.Destinations(review, query.Passwords, authority.Current, authority.IsLocked);
    }

    #endregion

    #region Actions - Finishing

    /// What finishing the setup open on this device does. Throws `Rejected`
    /// with `NoSetup` when none is open, `SetupBusy` while it reads or imports,
    /// and `PersistentWorkspaceRequired` over a workspace setup cannot change.
    public SetupFinish FinishingSetup() {
        SetupFlowState flow;
        lock (gate) flow = Idle(setupFlow ?? throw new Rejected(new NoSetup()));
        var authority = Attached(flow.WorkspaceId) ?? throw new Rejected(new NoSetup());
        if (!authority.Kind.KeepsAppPreferences) throw new Rejected(new PersistentWorkspaceRequired(flow.WorkspaceId));
        lock (gate) {
            var draft = flow.Step == SetupStep.ManualSetup && setupDraft?.WorkspaceId == flow.WorkspaceId ? setupDraft : null;
            return new(flow.WorkspaceId, draft is not null, flow.Entry.OpensGuide(setupCompleted), draft?.Spaces.Count(space => space.IsNew) ?? 0);
        }
    }

    /// Setup finished as `finish` said: this device has completed setup, the
    /// flow shows what it did, and the platform opens the guide in
    /// `guideSpaceId` when it names one.
    public void FinishedSetup(SetupFinish finish, Guid? guideSpaceId, ChangeFeed changes) {
        ArgumentNullException.ThrowIfNull(finish);
        ArgumentNullException.ThrowIfNull(changes);
        lock (gate) {
            if (!setupCompleted) {
                setupCompleted = true;
                storage?.EnqueueDevice(Records());
                changes.Publish(new SetupCompletedChanged(true));
            }
            if (setupFlow is { } flow)
                Publish(flow with {
                    Step = SetupStep.Complete,
                    Phase = SetupPhase.Idle,
                    Summary = finish.AppliesManualSetup ? new SetupSummary(IsImport: false, 0, 0, finish.CreatedSpaces) : flow.Summary
                }, changes);
            changes.Publish(new SetupFinished(finish.WorkspaceId, guideSpaceId));
        }
    }

    #endregion

    #region Actions - Completion

    /// Carries whether an installed release completed setup into the device
    /// store once, and publishes whether this device has. A device that keeps
    /// no file keeps what it is told for this run. The caller holds the device lock.
    private void Adopt(AdoptSetupCompletion intent, ChangeFeed changes) {
        if (storage is not { } target) setupCompleted = intent.Completed;
        else if (!adopted.Contains(DeviceAdoption.SetupCompletion)) {
            setupCompleted |= intent.Completed;
            adopted.Add(DeviceAdoption.SetupCompletion);
            target.EnqueueDevice(Records());
        }
        changes.Publish(new SetupCompletedChanged(setupCompleted));
    }

    #endregion

    #region Actions - Publishing

    /// Holds `flow` with where Back and Next lead from its step and what
    /// finishing opens, and publishes it. The flow setup already holds, which
    /// an intent that changed nothing answers, is not published again. The
    /// caller holds the device lock.
    private void Publish(SetupFlowState flow, ChangeFeed changes) {
        if (ReferenceEquals(flow, setupFlow)) return;
        bool opensGuide = flow.Entry.OpensGuide(setupCompleted);
        setupFlow = flow with {
            BackStep = flow.Step.Back(flow.Entry, platform),
            NextStep = flow.Step.Next(platform),
            OpensGuide = opensGuide,
            OpensCrestFromWelcome = setupCompleted && !opensGuide
        };
        changes.Publish(new SetupFlowChanged(setupFlow));
    }

    #endregion
}
