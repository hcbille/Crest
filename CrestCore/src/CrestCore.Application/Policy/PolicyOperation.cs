namespace CrestCore.Application;

internal enum PolicyOperation {
    Unknown,
    AuthenticationFixtureTrust,
    AuthenticationHandling,
    AuthenticationSourceLabel,
    DownloadsAutomatic,
    ExternalLocalDocument,
    ExternalScheme,
    ExternalUrl,
    GeolocationOrigin,
    Limits,
    MediaArbitrate,
    MediaSessionEvent,
    NavigationLink,
    NavigationModifiedLink,
    NotificationsOrigin,
    NotificationsPermissionRequest,
    OnboardingCompletion,
    OnboardingGuide,
    PopupsNotice,
    ResidencyProcessRecovery,
    ResidencyReleaseLimit,
    ResidencyReleasePlan,
    SetupReconcile,
    SetupSpace,
    SetupTab,
    // Links, Quick Windows, presentation, branding and workspace routing.
    LinksRouteCreate,
    LinksRouteMove,
    LinksRouteRemove,
    LinksRouteUpdate,
    LinksSpaceRemoved,
    QuickWindowDismissal,
    QuickWindowRetarget,
}

internal static class PolicyOperationCodes {
    #region Actions - Decoding

    public static PolicyOperation Parse(string? value) => value switch {
        "authentication.fixture_trust" => PolicyOperation.AuthenticationFixtureTrust,
        "authentication.handling" => PolicyOperation.AuthenticationHandling,
        "authentication.source_label" => PolicyOperation.AuthenticationSourceLabel,
        "downloads.automatic" => PolicyOperation.DownloadsAutomatic,
        "external.local_document" => PolicyOperation.ExternalLocalDocument,
        "external.scheme" => PolicyOperation.ExternalScheme,
        "external.url" => PolicyOperation.ExternalUrl,
        "geolocation.origin" => PolicyOperation.GeolocationOrigin,
        "limits" => PolicyOperation.Limits,
        "media.arbitrate" => PolicyOperation.MediaArbitrate,
        "media.session_event" => PolicyOperation.MediaSessionEvent,
        "navigation.link" => PolicyOperation.NavigationLink,
        "navigation.modified_link" => PolicyOperation.NavigationModifiedLink,
        "notifications.origin" => PolicyOperation.NotificationsOrigin,
        "notifications.permission_request" => PolicyOperation.NotificationsPermissionRequest,
        "onboarding.completion" => PolicyOperation.OnboardingCompletion,
        "onboarding.guide" => PolicyOperation.OnboardingGuide,
        "popups.notice" => PolicyOperation.PopupsNotice,
        "residency.process_recovery" => PolicyOperation.ResidencyProcessRecovery,
        "residency.release_limit" => PolicyOperation.ResidencyReleaseLimit,
        "residency.release_plan" => PolicyOperation.ResidencyReleasePlan,
        "setup.reconcile" => PolicyOperation.SetupReconcile,
        "setup.space" => PolicyOperation.SetupSpace,
        "setup.tab" => PolicyOperation.SetupTab,
        // Links, Quick Windows, presentation, branding and workspace routing.
        "links.route_create" => PolicyOperation.LinksRouteCreate,
        "links.route_move" => PolicyOperation.LinksRouteMove,
        "links.route_remove" => PolicyOperation.LinksRouteRemove,
        "links.route_update" => PolicyOperation.LinksRouteUpdate,
        "links.space_removed" => PolicyOperation.LinksSpaceRemoved,
        "quick_window.dismissal" => PolicyOperation.QuickWindowDismissal,
        "quick_window.retarget" => PolicyOperation.QuickWindowRetarget,
        _ => PolicyOperation.Unknown
    };

    #endregion
}
