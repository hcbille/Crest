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
public sealed class StandaloneAnswers : IQueryAnswers {
    #region Actions - Queries

    public TAnswer Query<TAnswer>(Query<TAnswer> query) {
        ArgumentNullException.ThrowIfNull(query);
        return (TAnswer)Answer(query);
    }

    /// The answer to a query that reads no state. Throws for any other.
    internal static object Answer(object query) => query switch {
        SamePage pages => new PageMatch(new WebAddress(pages.First).IsSamePage(new WebAddress(pages.Second))),
        HistoryAddresses addresses => new HistoryAddressList([.. addresses.Addresses.Select(address => new WebAddress(address).Normalized)]),
        LanguagesMatching matching => new LanguageMatches([.. matching.Candidates.Select(candidate =>
            LanguageTag.Matches(matching.Language, candidate))]),
        TranslationChoice choice => Decided(choice),
        ResolveAddress { WorkspaceId: null } address => NativeSessionAuthority.Resolved(address.Input, SearchProvider.Google,
            allowsInternalPages: false),
        FindImportData find => InstalledBrowser.Of(find.Source).Find(find.Folder),
        FirstInstallSession => FirstSession.FirstInstall(Guid.NewGuid, DateTimeOffset.UtcNow),
        DetachedSession detached => Detached(detached.Seed),
        LaunchIsolation launch => LaunchPolicy.Plan(launch.Environment, launch.Platform, storedStartup: null, hasActiveLaunchGate: false),
        NormalizeBranding branding => new NormalizedBranding(SpaceBrandingPolicy.Normalize(branding.Branding)),
        PresentPage page => new PagePresented(PagePresentation.Of(page)),
        ExternalWebLink link => new ExternalAddressVerdict(ExternalUrlPolicy.AcceptsWebLink(link.Scheme, link.Host)),
        ExternalLocalDocument document => new ExternalAddressVerdict(ExternalUrlPolicy.AcceptsLocalDocument(document.Facts)),
        SchemeHandling scheme => new SchemeHandled(ExternalSchemePolicy.Disposition(scheme.Scheme, scheme.AppInitiated)),
        ChallengeHandling challenge => new ChallengeHandled(AuthenticationPolicy.Handling(challenge.Method, challenge.IsProxy,
            challenge.PreviousFailureCount)),
        AuthenticationSource source => new AuthenticationSourceLabel(AuthenticationPolicy.SourceLabel(source.Host, source.Port,
            source.Scheme)),
        FixtureServerTrust trust => new FixtureServerTrusted(AuthenticationPolicy.TrustsPhysicalValidationServer(trust.BundleIdentifier,
            trust.ExpectedCertificateSha256, trust.ActualCertificateSha256)),
        MediaSessionReport report => MediaSessionPolicy.Decide(report.Event, report.Identity, report.RetainedIdentities,
            report.NextOrdinal),
        MediaSessionOrder order => MediaSessionPolicy.Arbitrate(order.Sessions),
        SecureOriginCheck origin => new SecureOriginVerdict(SecureOriginPolicy.Allows(origin.Origin)),
        NotificationPermissionRequest request => new NotificationRequestAnswer(HostedNotificationRequestAction.For(request.Decision,
            request.HasUserActivation)),
        BlockedPopupTransition popup => new BlockedPopupTransitioned(BlockedPopupPolicy.Apply(popup.State, popup.Event,
            popup.DocumentIdentifier, popup.Origin)),
        AutomaticDownloadCheck download => AutomaticDownloadPolicy.Decide(download.UserInitiated, download.UserApprovedRetry,
            download.SavedDecision, download.HasAllowedAutomaticDownload),
        EnforcedLimits => new CapacityLimits(BrowserLimits.Folders, BrowserLimits.FolderDepth, BrowserLimits.HistoryEntries,
            BrowserLimits.SplitMembers, BrowserLimits.BrandColors, BrowserLimits.CrestPalette, BrowserLimits.Spaces,
            BrowserLimits.TabsPerSpace, NativeSyncJournal.MaximumRecords, CredentialFile.MaximumBytes),
        _ => throw new ArgumentOutOfRangeException(nameof(query), query.GetType().Name, "No area answers this query.")
    };

    /// `seed` repaired as a stored session is when it loads, stamped as the
    /// session stores the time. Throws `Rejected` with `InvalidSession`
    /// naming the first rule it breaks that the repair cannot mend.
    private static SessionState Detached(SessionState seed) {
        var now = StoredSessionCodec.Date(StoredSessionCodec.Seconds(DateTimeOffset.UtcNow));
        SessionState repaired;
        try {
            repaired = NativeSessionMaintenance.Repair(seed, now, null, new SystemIdSource(), out _);
        } catch (BrowserRuleException) {
            throw new Rejected(new InvalidSession(SessionIdentities.Flaw(seed) ?? SessionFlaw.Unreadable));
        }
        return SessionIdentities.Flaw(repaired) is { } flaw ? throw new Rejected(new InvalidSession(flaw)) : repaired;
    }

    private static TranslationDecision Decided(TranslationChoice choice) {
        var rules = AutomaticTranslationRules.Restore(choice.Rules);
        return new(rules.Rule(choice.SourceLanguage), rules.Target(choice.SourceLanguage));
    }

    #endregion
}
