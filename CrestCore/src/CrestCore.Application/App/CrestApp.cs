using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The core's typed application API. An intent changes state and answers the
/// changes it published, or throws `Rejected`; a query answers without
/// changing anything. Each area handles its own intents and queries. One lock
/// serializes every call on this instance, except the cloud transport's: its
/// intents compute on the transport's thread and take the lock only to
/// commit, and its queries read the journal without it.
///
/// Changes the core starts itself, such as a finished save, a session commit,
/// a cloud merge or an engine's report, wait in a pending batch the host
/// drains after its wake callback runs. An intent the host sends answers that
/// batch first, so no older change arrives after a newer one. Commands for
/// engine bindings wait in a queue that is delivered once the lock is
/// released, on the thread of the host's call that caused them, or of its next
/// drain for those the transport caused.
public sealed partial class CrestApp : IQueryAnswers, IEngineAnswers, IDisposable,
    IIntentHandler<ChangeFeed, IReadOnlyList<Change>>, IPromptIntentHandler<ChangeFeed> {
    #region Variables

    private readonly Lock gate = new();
    private readonly Downloads downloads = new();
    private readonly Credentials credentials = new();
    private readonly ContentBlocking contentBlocking = new();
    /// This device's windows and what each shows.
    private readonly Device device;
    /// The pages this device hosts, and the engines that host them.
    private readonly Pages pages;
    /// The questions the pages and engines ask the person.
    private readonly Prompts prompts;
    /// The downloads engines run, in the download ledger.
    private readonly EngineDownloads engineDownloads;
    /// Close and quit preparations, which ask each page whether it may go.
    private readonly ClosePreparations closePreparations;
    /// Erasing what every engine keeps for a profile.
    private readonly DataDeletions dataDeletions;
    /// Which Spaces this process may show.
    private readonly SpaceAccess access;
    /// The cloud transport's state on this device.
    private readonly CloudTransportStore cloudTransport;
    /// What iCloud sync does next on this device.
    private readonly CloudSyncControl cloudSync;
    /// The time session intents are stamped with.
    private readonly IClock clock;
    /// Where the identities the core gives new records come from.
    private readonly IIdSource ids;
    /// Reading other browsers' data and browser-data files, and exports.
    private readonly Portability portability;

    #endregion

    #region Constructors

    /// A core that keeps everything in memory.
    public CrestApp() : this(new AppConfiguration(null, DevicePlatform.Desktop)) { }

    /// A core configured by the host. With a storage directory it opens the
    /// session file there and loads the session it holds; throws `Rejected`
    /// when the file cannot be used.
    public CrestApp(AppConfiguration configuration) : this(configuration, new SystemClock(), new SystemIdSource()) { }

    /// A core that reads the time from `clock` and draws new identities from `ids`.
    internal CrestApp(AppConfiguration configuration, IClock clock, IIdSource ids) {
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(clock);
        ArgumentNullException.ThrowIfNull(ids);
        this.clock = clock;
        this.ids = ids;
        portability = new(configuration.ImportNames, clock, ids);
        dataDeletions = new(engines, ids);
        // One grant authority for the process: every session the device shows
        // consults it, so a borrowed workspace unlocks with its source.
        var grants = new SpaceAccessAuthority();
        if (configuration.StorageDirectory is not { } directory) {
            device = new(configuration.Platform, storage: null, DeviceRecords.Empty, grants, Announce, RequestTurn, CloseBorrower);
            pages = new(device, engines, clock, ids);
            prompts = new(device, pages);
            engineDownloads = new(downloads, device, pages, ids);
            closePreparations = new(pages, downloads, ids);
            access = new(device, grants);
            cloudTransport = new(storage: null, device);
            cloudSync = new(cloudTransport, clock, StoredSessionIsDisposableSeed);
            return;
        }
        storage = SessionStorage.Open(directory, Announce, out var loaded);
        device = new(configuration.Platform, storage, storage.Device, grants, Announce, RequestTurn, CloseBorrower);
        pages = new(device, engines, clock, ids);
        prompts = new(device, pages);
        engineDownloads = new(downloads, device, pages, ids);
        closePreparations = new(pages, downloads, ids);
        access = new(device, grants);
        cloudTransport = new(storage, device);
        cloudSync = new(cloudTransport, clock, StoredSessionIsDisposableSeed);
        try {
            if (loaded.Session is { } stored) Establish(stored, loaded.Journal, loaded.LegacySelection);
        } catch (Exception error) {
            storage.Dispose();
            if (error is Rejected) throw;
            throw new Rejected(new StorageUnreadable(StorageFailure.Damaged));
        }
    }

    #endregion

    #region Actions - Intents

    /// The changes still pending when the intent ran and those it published
    /// there, in the order they happened, then the changes the intent itself
    /// published. An intent that does not apply to the current state publishes
    /// none. Engine commands the intent caused have been delivered when this
    /// returns, unless it runs inside a delivery. A `CloudSyncIntent` answers
    /// only its receipts; see `Handle(CloudSyncIntent)`.
    public IReadOnlyList<Change> Send(Intent intent) {
        ArgumentNullException.ThrowIfNull(intent);
        return intent.Dispatch(this, new ChangeFeed());
    }

    /// Runs `work`, an intent's own, holding the lock, then settles what any
    /// intent leaves behind, and delivers the engine commands they caused once
    /// the lock is released. Answers the pending changes, then `changes`.
    private IReadOnlyList<Change> Sending(ChangeFeed changes, Action work) {
        IReadOnlyList<Change> published;
        lock (gate) {
            work();
            // Which pages windows show now, and what closed tabs no longer keep.
            pages.Stamp(clock.Now);
            pages.PruneRestoreStates();
            // What a page that went had asked no longer waits.
            prompts.Prune(changes);
            closePreparations.Prune(changes, Issue);
            published = [.. TakePending(), .. changes.Published];
        }
        Deliver();
        WakeForRequestedTurn();
        return published;
    }

    // The cloud transport's intents run on its thread, outside the lock.
    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(CloudSyncIntent intent, ChangeFeed changes) => Handle(intent);

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(CloudTransportIntent intent, ChangeFeed changes) =>
        cloudTransport.Handle(intent, JournalHoldsUploads);

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(CloudSyncControlIntent intent, ChangeFeed changes) => cloudSync.Handle(intent);

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(DownloadIntent intent, ChangeFeed changes) => Sending(changes, () => {
        engineDownloads.Before(intent, changes, Issue);
        downloads.Handle(intent, changes);
    });

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(AdoptLegacySession intent, ChangeFeed changes) => Sending(changes, () => Adopt(intent, changes));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(WorkspaceIntent intent, ChangeFeed changes) =>
        Sending(changes, () => intent.Dispatch(this, changes));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(WindowIntent intent, ChangeFeed changes) => Sending(changes, () => {
        device.Handle(intent, changes);
        pages.RecoverShown(changes, Issue);
    });

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(SitePermissionIntent intent, ChangeFeed changes) =>
        Sending(changes, () => device.Handle(intent, new SitePermissionTurn(changes, clock.Now, ids)));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(ChooseSiteEngine choice, ChangeFeed changes) => Sending(changes, () => {
        if (engines.Registered(choice.Engine) is null) throw new Rejected(new UnregisteredEngine(choice.Engine));
        device.Choose(choice);
    });

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(ShortcutIntent intent, ChangeFeed changes) =>
        Sending(changes, () => device.Handle(intent, new ShortcutTurn(Engines.OfferedCommands(RegisteredEngines()), changes)));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(LinkIntent intent, ChangeFeed changes) => Sending(changes, () => device.Handle(intent, changes));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(SetupDraftIntent intent, ChangeFeed changes) =>
        Sending(changes, () => device.Handle(intent, new SetupDraftTurn(changes, ids)));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(SetupFlowIntent intent, ChangeFeed changes) =>
        Sending(changes, () => device.Handle(intent, new SetupFlowTurn(changes, ids, finish => Finish(finish, changes))));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(PageIntent intent, ChangeFeed changes) => Sending(changes, () => {
        pages.Handle(intent, new PageTurn(changes, Issue));
        PublishEngines(changes.Publish);
    });

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(DataDeletionIntent intent, ChangeFeed changes) =>
        Sending(changes, () => dataDeletions.Handle(intent, new DeletionTurn(changes, Issue)));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(SessionIntent session, ChangeFeed changes) => Sending(changes, () => {
        if (session is FinishDeletingSpace finishing) RequireErased(finishing);
        device.Workspace(session.WorkspaceId).Handle(session, clock.Now, ids, pages);
        if (session is PromoteTransientPage promoted) pages.Completed(promoted.PageId);
        else if (session is ArchiveTransientPage archived) pages.Completed(archived.PageId);
        // A deleted Space leaves nothing in this device's link preferences.
        else if (session is FinishDeletingSpace deleted) device.ForgetLinks(deleted.SpaceId, changes);
        // An applied manual setup ends.
        else if (session is ApplyManualSetup applied) device.FinishManualSetup(applied.WorkspaceId, changes);
    });

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(SpaceAccessIntent intent, ChangeFeed changes) => Sending(changes, () => access.Handle(intent, changes));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(CloseIntent intent, ChangeFeed changes) =>
        Sending(changes, () => closePreparations.Handle(intent, new CloseTurn(changes, Issue)));

    IReadOnlyList<Change> IIntentHandler<ChangeFeed, IReadOnlyList<Change>>.Handle(PromptIntent intent, ChangeFeed changes) => Sending(changes, () => intent.Dispatch(this, changes));

    /// A Space's deletion finishes only once this run erased its profile's
    /// data on every registered engine. Throws `Rejected` otherwise; a Space
    /// the session no longer holds is the session's to refuse.
    private void RequireErased(FinishDeletingSpace finishing) {
        if (device.Workspace(finishing.WorkspaceId).Current.Spaces.FirstOrDefault(space => space.Id == finishing.SpaceId) is { } space
            && !dataDeletions.Erased(space.ProfileId))
            throw new Rejected(new SpaceDataNotErased(space.Id));
    }

    #endregion

    #region Actions - Prompts

    // Each answer goes to the area that asked its question. The caller holds the lock.

    void IPromptIntentHandler<ChangeFeed>.Handle(AnswerAuthentication answer, ChangeFeed changes) => prompts.Handle(answer, changes, Issue, clock.Now, ids);

    void IPromptIntentHandler<ChangeFeed>.Handle(AnswerExtensionInstall answer, ChangeFeed changes) => prompts.Handle(answer, changes, Issue, clock.Now, ids);

    void IPromptIntentHandler<ChangeFeed>.Handle(AnswerPermission answer, ChangeFeed changes) => prompts.Handle(answer, changes, Issue, clock.Now, ids);

    void IPromptIntentHandler<ChangeFeed>.Handle(AnswerScriptDialog answer, ChangeFeed changes) => prompts.Handle(answer, changes, Issue, clock.Now, ids);

    void IPromptIntentHandler<ChangeFeed>.Handle(AnswerDownloadApproval answer, ChangeFeed changes) => engineDownloads.Handle(answer, changes, Issue);

    void IPromptIntentHandler<ChangeFeed>.Handle(AnswerDownloadDestination answer, ChangeFeed changes) => engineDownloads.Handle(answer, changes, Issue);

    void IPromptIntentHandler<ChangeFeed>.Handle(AnswerQuitWithDownloads answer, ChangeFeed changes) => closePreparations.Handle(answer, changes);

    #endregion

    #region Actions - Lifetime

    /// Stages and saves any accepted revision still pending and closes the
    /// session file. The stored session accepts no edits afterwards, and no
    /// engine binding hears from the core again.
    public void Dispose() {
        lock (gate) engines.Clear();
        storedSync?.Stop();
        storedSession?.Close();
        storage?.Dispose();
    }

    #endregion
}
