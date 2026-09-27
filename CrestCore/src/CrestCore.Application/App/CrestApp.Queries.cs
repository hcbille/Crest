using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

public sealed partial class CrestApp : IQueryHandler<DateTimeOffset> {
    #region Static Variables

    /// Answers the questions that read no state, as a host without an app
    /// asks them.
    private static readonly StandaloneAnswers Standalone = new();

    #endregion

    #region Actions - Queries

    /// Answers `query` as the core stands when it is asked. The questions the
    /// cloud transport asks, reading other browsers' data and files, and the
    /// ones that read no state hold no lock; the others read the core's state
    /// holding it.
    public TAnswer Query<TAnswer>(Query<TAnswer> query) {
        ArgumentNullException.ThrowIfNull(query);
        return query.Dispatch(this, clock.Now);
    }

    TAnswer IQueryHandler<DateTimeOffset>.Handle<TAnswer>(StandaloneQuery<TAnswer> query, DateTimeOffset now) => query.Dispatch(Standalone, now);

    /// An address resolves by the rules of the workspace it names, and alone
    /// by the default rules when it names none.
    ResolvedAddress IQueryHandler<DateTimeOffset>.Handle(ResolveAddress address, DateTimeOffset now) => address.WorkspaceId is { } workspace
        ? Reading(() => device.Workspace(workspace).Answer(address, pages.OpensInternalPages))
        : StandaloneAnswers.Resolve(address);

    // The cloud transport's questions read the journal and its own state.

    PendingUploadList IQueryHandler<DateTimeOffset>.Handle(PendingUploads query, DateTimeOffset now) => StoredSyncSession().Answer(query);

    UploadBatch IQueryHandler<DateTimeOffset>.Handle(RecordsToUpload query, DateTimeOffset now) => StoredSyncSession().Answer(query);

    CloudContentComparison IQueryHandler<DateTimeOffset>.Handle(CloudComparison query, DateTimeOffset now) => StoredSyncSession().Answer(query);

    CloudTransportState IQueryHandler<DateTimeOffset>.Handle(CloudTransport query, DateTimeOffset now) => cloudTransport.Answer(query);

    CloudRecordFieldList IQueryHandler<DateTimeOffset>.Handle(CloudFieldsOf query, DateTimeOffset now) => cloudTransport.Answer(query);

    CloudSyncStatus IQueryHandler<DateTimeOffset>.Handle(CloudSync query, DateTimeOffset now) => cloudSync.Answer(query);

    // Reading other browsers' data, files and exports holds the lock only to
    // read what they start from.

    PaletteAnswer IQueryHandler<DateTimeOffset>.Handle(PaletteSuggestions query, DateTimeOffset now) => Suggesting(query);

    ImportedSpaces IQueryHandler<DateTimeOffset>.Handle(ReadImport query, DateTimeOffset now) => portability.Answer(query);

    ImportedSpaces IQueryHandler<DateTimeOffset>.Handle(ReadArchive query, DateTimeOffset now) => portability.Answer(query);

    CredentialImportPlan IQueryHandler<DateTimeOffset>.Handle(CredentialImportPreview query, DateTimeOffset now) => credentials.Answer(query);

    CredentialImportPlan IQueryHandler<DateTimeOffset>.Handle(PasswordImportPreview query, DateTimeOffset now) => credentials.Answer(query);

    CredentialExportFile IQueryHandler<DateTimeOffset>.Handle(CredentialExport query, DateTimeOffset now) => credentials.Answer(query);

    ExportedDocument IQueryHandler<DateTimeOffset>.Handle(ExportWorkspace query, DateTimeOffset now) => Exporting(query);

    // The rest read the core's state holding the lock.

    DownloadProgressReading IQueryHandler<DateTimeOffset>.Handle(DownloadProgress query, DateTimeOffset now) =>
        Reading(() => downloads.Answer(query));

    DownloadRiskVerdict IQueryHandler<DateTimeOffset>.Handle(DownloadRisk query, DateTimeOffset now) => Reading(() => downloads.Answer(query));

    CredentialCaptureDecision IQueryHandler<DateTimeOffset>.Handle(CredentialCapture query, DateTimeOffset now) =>
        Reading(() => credentials.Answer(query));

    CredentialFillDecision IQueryHandler<DateTimeOffset>.Handle(CredentialFill query, DateTimeOffset now) =>
        Reading(() => credentials.Answer(query));

    CredentialSaveVerdict IQueryHandler<DateTimeOffset>.Handle(CredentialSaveCheck query, DateTimeOffset now) =>
        Reading(() => credentials.Answer(query));

    CredentialChoice IQueryHandler<DateTimeOffset>.Handle(MostRecentCredential query, DateTimeOffset now) => Reading(() => credentials.Answer(query));

    CredentialChoice IQueryHandler<DateTimeOffset>.Handle(CredentialSaveMatch query, DateTimeOffset now) => Reading(() => credentials.Answer(query));

    CredentialSavePlan IQueryHandler<DateTimeOffset>.Handle(CredentialSave query, DateTimeOffset now) => Reading(() => credentials.Answer(query));

    StrongPasswordRecipe IQueryHandler<DateTimeOffset>.Handle(StrongPassword query, DateTimeOffset now) => Reading(() => credentials.Answer(query));

    PasskeyAccessVerdict IQueryHandler<DateTimeOffset>.Handle(PasskeyAccess query, DateTimeOffset now) => Reading(() => credentials.Answer(query));

    SystemPasswordWriteThroughSupport IQueryHandler<DateTimeOffset>.Handle(SystemPasswordWriteThrough query, DateTimeOffset now) =>
        Reading(() => credentials.Answer(query));

    SystemPasswordOfferDecision IQueryHandler<DateTimeOffset>.Handle(SystemPasswordOffer query, DateTimeOffset now) =>
        Reading(() => credentials.Answer(query));

    ContentRuleList IQueryHandler<DateTimeOffset>.Handle(BalancedProtectionRules query, DateTimeOffset now) =>
        Reading(() => contentBlocking.Answer(query));

    ExternalLinkPlacement IQueryHandler<DateTimeOffset>.Handle(RouteExternalLink query, DateTimeOffset now) => Reading(() => device.Answer(query));

    LinkNavigationAnswer IQueryHandler<DateTimeOffset>.Handle(LinkNavigation query, DateTimeOffset now) =>
        Reading(() => device.Answer(query, pages));

    OpenedWindowSelected IQueryHandler<DateTimeOffset>.Handle(OpenedWindowSelection query, DateTimeOffset now) =>
        Reading(() => device.Answer(query));

    TearOffPermission IQueryHandler<DateTimeOffset>.Handle(CanTearOff query, DateTimeOffset now) => Reading(() => device.Answer(query));

    SitePermissionAnswer IQueryHandler<DateTimeOffset>.Handle(SiteDecision query, DateTimeOffset now) => Reading(() => device.Answer(query));

    ImportPasswordRoutes IQueryHandler<DateTimeOffset>.Handle(ImportPasswordDestinations query, DateTimeOffset now) =>
        Reading(() => device.Answer(query));

    SitePermissionAnswer IQueryHandler<DateTimeOffset>.Handle(CaptureDecision query, DateTimeOffset now) => Reading(() => device.Answer(query));

    NumberedSelectionList IQueryHandler<DateTimeOffset>.Handle(NumberedSelections query, DateTimeOffset now) =>
        Reading(() => device.Answer(query));

    SplitJoinCandidateTab IQueryHandler<DateTimeOffset>.Handle(SplitJoinCandidate query, DateTimeOffset now) =>
        Reading(() => device.Answer(query, now, pages));

    DropTargetList IQueryHandler<DateTimeOffset>.Handle(DropTargets query, DateTimeOffset now) => Reading(() => device.Answer(query, now, pages));

    SelectedTabs IQueryHandler<DateTimeOffset>.Handle(SelectionPreview query, DateTimeOffset now) =>
        Reading(() => device.Workspace(query.WorkspaceId).Answer(query));

    SavedAddressReturn IQueryHandler<DateTimeOffset>.Handle(CanReturnToSavedAddress query, DateTimeOffset now) =>
        Reading(() => pages.Answer(query));

    FallbackTabIndex IQueryHandler<DateTimeOffset>.Handle(FallbackTab query, DateTimeOffset now) => Reading(() => Window.Answer(query));

    PendingSaveRevision IQueryHandler<DateTimeOffset>.Handle(PendingSave query, DateTimeOffset now) =>
        Reading(() => new PendingSaveRevision(storage?.PendingRevision is { } revision ? checked((long)revision) : null));

    SendPermission IQueryHandler<DateTimeOffset>.Handle(CanSend query, DateTimeOffset now) => Reading(() => Permission(query.Intent, now));

    LaunchDecision IQueryHandler<DateTimeOffset>.Handle(LaunchPlan query, DateTimeOffset now) =>
        Reading(() => device.Workspace(query.WorkspaceId).Plan(query));

    ImportedWorkspace IQueryHandler<DateTimeOffset>.Handle(ImportPreview query, DateTimeOffset now) =>
        Reading(() => device.Workspace(query.Import.WorkspaceId).Preview(query.Import, now));

    SelectionSearchAnswer IQueryHandler<DateTimeOffset>.Handle(SelectionSearch query, DateTimeOffset now) =>
        Reading(() => device.Workspace(query.WorkspaceId).Answer(query));

    /// What `read` answers from the core's state, holding the lock.
    private T Reading<T>(Func<T> read) {
        lock (gate) return read();
    }

    /// The file an export writes. Only reading the session holds the lock;
    /// writing the file reads immutable records outside it.
    private ExportedDocument Exporting(ExportWorkspace export) {
        SessionState session;
        lock (gate) session = device.Workspace(export.WorkspaceId).Exported();
        return portability.Export(session, export.Format);
    }

    /// What a window's palette offers. Only reading what the window shows
    /// holds the lock; ranking reads immutable records outside it, so a
    /// palette answering on another thread never holds up the window.
    private PaletteAnswer Suggesting(PaletteSuggestions question) {
        Palette palette;
        lock (gate) palette = device.Palette(question.WindowId, pages.OpensInternalPages);
        return palette.Answer(question.Text, question.Commands, question.Remote);
    }

    /// Whether the core would accept a session intent at `now`: the rule that
    /// would refuse it, or none. The identities a check draws are never used.
    /// The caller holds the lock.
    private SendPermission Permission(Intent intent, DateTimeOffset now) {
        if (intent is not SessionIntent session)
            throw new ArgumentOutOfRangeException(nameof(intent), intent.GetType().Name, "Only a session intent can be checked.");
        try {
            device.Workspace(session.WorkspaceId).Check(session, now, new SystemIdSource(), pages);
            return new(Refusal: null);
        } catch (Rejected refused) {
            return new(refused.Rejection);
        }
    }

    #endregion
}
