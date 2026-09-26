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
public sealed partial class CrestApp : IQueryAnswers, IDisposable {
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
    /// Which Spaces this process may show.
    private readonly SpaceAccess access;
    /// The time session intents are stamped with.
    private readonly IClock clock;
    /// Where the identities the core gives new records come from.
    private readonly IIdSource ids;

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
            return;
        }
        storage = SessionStorage.Open(directory, Announce, out var loaded);
        device = new(configuration.Platform, storage, storage.Device, grants, Announce, RequestTurn, CloseBorrower);
        pages = new(device, engines, clock, ids);
        prompts = new(device, pages);
        engineDownloads = new(downloads, device, pages, ids);
        closePreparations = new(pages, downloads, ids);
        access = new(device, grants);
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
        if (intent is CloudSyncIntent cloud) return Handle(cloud);
        IReadOnlyList<Change> published;
        lock (gate) {
            var changes = new ChangeFeed();
            switch (intent) {
                case DownloadIntent download:
                    engineDownloads.Before(download, changes, Issue);
                    downloads.Handle(download, changes);
                    break;
                case AdoptLegacySession adoption:
                    Adopt(adoption, changes);
                    break;
                case WorkspaceIntent workspace:
                    Handle(workspace);
                    break;
                case WindowIntent window:
                    device.Handle(window, changes);
                    pages.RecoverShown(changes, Issue);
                    break;
                case SitePermissionIntent permission:
                    device.Handle(permission, changes, clock.Now, ids);
                    break;
                case ShortcutIntent shortcut:
                    device.Handle(shortcut, engines.OfferedCommands(), changes);
                    break;
                case LinkIntent link:
                    device.Handle(link, changes);
                    break;
                case PageIntent page:
                    pages.Handle(page, changes, Issue);
                    break;
                case SessionIntent session:
                    device.Workspace(session.WorkspaceId).Handle(session, clock.Now, ids, pages);
                    if (session is PromoteTransientPage promoted) pages.Completed(promoted.PageId);
                    else if (session is ArchiveTransientPage archived) pages.Completed(archived.PageId);
                    // A deleted Space leaves nothing in this device's link preferences.
                    else if (session is FinishDeletingSpace deleted) device.ForgetLinks(deleted.SpaceId, changes);
                    break;
                case SpaceAccessIntent grant:
                    access.Handle(grant, changes);
                    break;
                case CloseIntent closing:
                    closePreparations.Handle(closing, changes, Issue);
                    break;
                case PromptIntent prompt when ClosePreparations.Concerns(prompt):
                    closePreparations.Handle(prompt, changes);
                    break;
                case PromptIntent prompt when EngineDownloads.Concerns(prompt):
                    engineDownloads.Handle(prompt, changes, Issue);
                    break;
                case PromptIntent prompt:
                    prompts.Handle(prompt, changes, Issue, clock.Now, ids);
                    break;
                default:
                    throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "No area handles this intent.");
            }
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

    #endregion

    #region Actions - Queries

    public TAnswer Query<TAnswer>(Query<TAnswer> query) {
        ArgumentNullException.ThrowIfNull(query);
        object? transport = query switch {
            PendingUploads pending => Answer(pending),
            RecordsToUpload upload => Answer(upload),
            CloudComparison comparison => Answer(comparison),
            _ => null
        };
        if (transport is not null) return (TAnswer)transport;
        if (query is PaletteSuggestions palette) return (TAnswer)(object)Suggesting(palette);
        lock (gate) {
            object answer = query switch {
                DownloadProgress progress => downloads.Answer(progress),
                DownloadRisk risk => downloads.Answer(risk),
                CredentialCapture capture => credentials.Answer(capture),
                CredentialFill fill => credentials.Answer(fill),
                CredentialSaveCheck check => credentials.Answer(check),
                MostRecentCredential recency => credentials.Answer(recency),
                CredentialSaveMatch match => credentials.Answer(match),
                CredentialSave save => credentials.Answer(save),
                StrongPassword password => credentials.Answer(password),
                PasskeyAccess access => credentials.Answer(access),
                SystemPasswordWriteThrough writeThrough => credentials.Answer(writeThrough),
                SystemPasswordOffer offer => credentials.Answer(offer),
                BalancedProtectionRules rules => contentBlocking.Answer(rules),
                RouteExternalLink route => device.Answer(route),
                LinkNavigation navigation => device.Answer(navigation, pages),
                OpenedWindowSelection selection => device.Answer(selection),
                CanTearOff tearOff => device.Answer(tearOff),
                SiteDecision decision => device.Answer(decision),
                CaptureDecision capture => device.Answer(capture),
                NumberedSelections numbered => device.Answer(numbered),
                SplitJoinCandidate candidate => device.Answer(candidate, clock.Now, pages),
                DropTargets targets => device.Answer(targets, clock.Now, pages),
                SelectionPreview preview => device.Workspace(preview.WorkspaceId).Answer(preview),
                CanReturnToSavedAddress savedAddress => pages.Answer(savedAddress),
                FallbackTab fallback => Window.Answer(fallback),
                PendingSave => new PendingSaveRevision(storage?.PendingRevision is { } revision ? checked((long)revision) : null),
                CanSend check => Permission(check.Intent),
                LaunchPlan plan => device.Workspace(plan.WorkspaceId).Plan(plan),
                ImportPreview preview => device.Workspace(preview.Import.WorkspaceId).Preview(preview.Import, clock.Now),
                ImportReviewSuggestions suggestions => device.Workspace(suggestions.WorkspaceId).Answer(suggestions),
                ImportReviewAnalysis analysis => device.Workspace(analysis.WorkspaceId).Answer(analysis),
                ResolveAddress { WorkspaceId: { } workspace } address => device.Workspace(workspace).Answer(address, pages.OpensInternalPages),
                SelectionSearch search => device.Workspace(search.WorkspaceId).Answer(search),
                _ => StandaloneAnswers.Answer(query)
            };
            return (TAnswer)answer;
        }
    }

    /// What a window's palette offers. Only reading what the window shows
    /// holds the lock; ranking reads immutable records outside it, so a
    /// palette answering on another thread never holds up the window.
    private PaletteAnswer Suggesting(PaletteSuggestions question) {
        Palette palette;
        lock (gate) palette = device.Palette(question.WindowId, pages.OpensInternalPages);
        return palette.Answer(question.Text, question.Commands, question.Remote);
    }

    /// Whether the core would accept a session intent now: the rule that would
    /// refuse it, or none. The identities a check draws are never used.
    private SendPermission Permission(Intent intent) {
        if (intent is not SessionIntent session)
            throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "Only a session intent can be checked.");
        try {
            device.Workspace(session.WorkspaceId).Check(session, clock.Now, new SystemIdSource(), pages);
            return new(Refusal: null);
        } catch (Rejected refused) {
            return new(refused.Rejection);
        }
    }

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
