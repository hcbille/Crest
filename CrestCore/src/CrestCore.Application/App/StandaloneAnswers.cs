using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The queries that read no state: whether two addresses name one page, the
/// addresses history keeps for others, how translation languages match, which
/// translation rule applies, what an address typed outside any workspace
/// loads, how a launch treats the person's data, the session a seed opens
/// as, branding as a Space keeps it, what a page surface shows, which
/// addresses and schemes Crest takes from outside, how it answers an
/// authentication challenge, how page media sessions order, what a site's
/// origin, notification request, blocked popup or automatic download leads
/// to, and the capacities the core enforces. A host asks them before it has
/// an app, or from code that holds none; an app answers them the same way.
public sealed class StandaloneAnswers : IQueryAnswers, IStandaloneQueryHandler<DateTimeOffset> {
    #region Actions - Queries

    public TAnswer Query<TAnswer>(Query<TAnswer> query) {
        ArgumentNullException.ThrowIfNull(query);
        if (query is StandaloneQuery<TAnswer> alone) return alone.Dispatch(this, DateTimeOffset.UtcNow);
        // An address that names no workspace resolves by the default rules;
        // one that names a workspace reads its Space, which only an app holds.
        if (query is ResolveAddress { WorkspaceId: null } address) return (TAnswer)(object)Resolve(address);
        throw new ArgumentOutOfRangeException(nameof(query), query.GetType().Name, "No area answers this query.");
    }

    /// What an address typed outside any workspace loads: Google searches
    /// what is not an address, and no internal page opens.
    internal static ResolvedAddress Resolve(ResolveAddress address) =>
        NativeSessionAuthority.Resolved(address.Input, SearchProvider.Google, allowsInternalPages: false);

    PageMatch IStandaloneQueryHandler<DateTimeOffset>.Handle(SamePage pages, DateTimeOffset now) =>
        new(new WebAddress(pages.First).IsSamePage(new WebAddress(pages.Second)));

    HistoryAddressList IStandaloneQueryHandler<DateTimeOffset>.Handle(HistoryAddresses addresses, DateTimeOffset now) =>
        new([.. addresses.Addresses.Select(address => new WebAddress(address).Normalized)]);

    LanguageMatches IStandaloneQueryHandler<DateTimeOffset>.Handle(LanguagesMatching matching, DateTimeOffset now) =>
        new([.. matching.Candidates.Select(candidate => LanguageTag.Matches(matching.Language, candidate))]);

    TranslationDecision IStandaloneQueryHandler<DateTimeOffset>.Handle(TranslationChoice choice, DateTimeOffset now) {
        var rules = AutomaticTranslationRules.Restore(choice.Rules);
        return new(rules.Rule(choice.SourceLanguage), rules.Target(choice.SourceLanguage));
    }

    ImportData IStandaloneQueryHandler<DateTimeOffset>.Handle(FindImportData find, DateTimeOffset now) => InstalledBrowser.Of(find.Source).Find(find.Folder);

    SessionState IStandaloneQueryHandler<DateTimeOffset>.Handle(FirstInstallSession first, DateTimeOffset now) => FirstSession.FirstInstall(Guid.NewGuid, now);

    /// The seed repaired as a stored session is when it loads, stamped as the
    /// session stores the time. Throws `Rejected` with `InvalidSession`
    /// naming the first rule it breaks that the repair cannot mend.
    SessionState IStandaloneQueryHandler<DateTimeOffset>.Handle(DetachedSession detached, DateTimeOffset now) {
        var seed = detached.Seed;
        var stamped = StoredSessionCodec.Date(StoredSessionCodec.Seconds(now));
        SessionState repaired;
        try {
            repaired = NativeSessionMaintenance.Repair(seed, stamped, null, new SystemIdSource(), out _);
        } catch (BrowserRuleException) {
            throw new Rejected(new InvalidSession(SessionIdentities.Flaw(seed) ?? SessionFlaw.Unreadable));
        }
        return SessionIdentities.Flaw(repaired) is { } flaw ? throw new Rejected(new InvalidSession(flaw)) : repaired;
    }

    LaunchDecision IStandaloneQueryHandler<DateTimeOffset>.Handle(LaunchIsolation launch, DateTimeOffset now) =>
        LaunchPolicy.Plan(launch.Environment, launch.Platform, storedStartup: null, hasActiveLaunchGate: false);

    NormalizedBranding IStandaloneQueryHandler<DateTimeOffset>.Handle(NormalizeBranding branding, DateTimeOffset now) => new(SpaceBrandingPolicy.Normalize(branding.Branding));

    PagePresented IStandaloneQueryHandler<DateTimeOffset>.Handle(PresentPage page, DateTimeOffset now) => new(PagePresentation.Of(page));

    ExternalAddressVerdict IStandaloneQueryHandler<DateTimeOffset>.Handle(ExternalWebLink link, DateTimeOffset now) => new(ExternalUrlPolicy.AcceptsWebLink(link.Scheme, link.Host));

    ExternalAddressVerdict IStandaloneQueryHandler<DateTimeOffset>.Handle(ExternalLocalDocument document, DateTimeOffset now) =>
        new(ExternalUrlPolicy.AcceptsLocalDocument(document.Facts));

    SchemeHandled IStandaloneQueryHandler<DateTimeOffset>.Handle(SchemeHandling scheme, DateTimeOffset now) =>
        new(ExternalSchemePolicy.Disposition(scheme.Scheme, scheme.AppInitiated));

    ChallengeHandled IStandaloneQueryHandler<DateTimeOffset>.Handle(ChallengeHandling challenge, DateTimeOffset now) =>
        new(AuthenticationPolicy.Handling(challenge.Method, challenge.IsProxy, challenge.PreviousFailureCount));

    AuthenticationSourceLabel IStandaloneQueryHandler<DateTimeOffset>.Handle(AuthenticationSource source, DateTimeOffset now) =>
        new(AuthenticationPolicy.SourceLabel(source.Host, source.Port, source.Scheme));

    FixtureServerTrusted IStandaloneQueryHandler<DateTimeOffset>.Handle(FixtureServerTrust trust, DateTimeOffset now) =>
        new(AuthenticationPolicy.TrustsPhysicalValidationServer(trust.BundleIdentifier, trust.ExpectedCertificateSha256,
            trust.ActualCertificateSha256));

    MediaSessionEventDecision IStandaloneQueryHandler<DateTimeOffset>.Handle(MediaSessionReport report, DateTimeOffset now) =>
        MediaSessionPolicy.Decide(report.Event, report.Identity, report.RetainedIdentities, report.NextOrdinal);

    MediaSessionArbitration IStandaloneQueryHandler<DateTimeOffset>.Handle(MediaSessionOrder order, DateTimeOffset now) => MediaSessionPolicy.Arbitrate(order.Sessions);

    SecureOriginVerdict IStandaloneQueryHandler<DateTimeOffset>.Handle(SecureOriginCheck origin, DateTimeOffset now) => new(SecureOriginPolicy.Allows(origin.Origin));

    NotificationRequestAnswer IStandaloneQueryHandler<DateTimeOffset>.Handle(NotificationPermissionRequest request, DateTimeOffset now) =>
        new(HostedNotificationRequestAction.For(request.Decision, request.HasUserActivation));

    BlockedPopupTransitioned IStandaloneQueryHandler<DateTimeOffset>.Handle(BlockedPopupTransition popup, DateTimeOffset now) =>
        new(BlockedPopupPolicy.Apply(popup.State, popup.Event, popup.DocumentIdentifier, popup.Origin));

    AutomaticDownloadVerdict IStandaloneQueryHandler<DateTimeOffset>.Handle(AutomaticDownloadCheck download, DateTimeOffset now) =>
        AutomaticDownloadPolicy.Decide(download.UserInitiated, download.UserApprovedRetry, download.SavedDecision,
            download.HasAllowedAutomaticDownload);

    CapacityLimits IStandaloneQueryHandler<DateTimeOffset>.Handle(EnforcedLimits limits, DateTimeOffset now) =>
        new(BrowserLimits.Folders, BrowserLimits.FolderDepth, BrowserLimits.HistoryEntries, BrowserLimits.SplitMembers,
            BrowserLimits.BrandColors, BrowserLimits.CrestPalette, BrowserLimits.Spaces, BrowserLimits.TabsPerSpace,
            NativeSyncJournal.MaximumRecords, CredentialFile.MaximumBytes);

    #endregion
}
