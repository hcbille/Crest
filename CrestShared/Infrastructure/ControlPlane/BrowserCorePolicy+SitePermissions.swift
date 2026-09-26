import Foundation

/// Site-permission rules answered by the portable core: secure origins for
/// location and hosted notifications, the notification request action, the
/// blocked-popup notice transitions and automatic downloads. Saved choices
/// themselves live in the core ledger behind `BrowserSitePermissionCenter`,
/// and what a decision means travels with the decision. Every answer fails
/// closed.
extension BrowserCorePolicy {
    // MARK: - Actions - Site permissions

    /// Whether a site may use location at all. An unavailable core refuses.
    static func allowsGeolocation(for origin: SiteOrigin) -> Bool {
        (try? CrestCore.answer(SecureOriginCheck(origin: origin)))?.allowed ?? false
    }

    /// Whether a site may post hosted web notifications at all. An unavailable core refuses.
    static func allowsHostedNotifications(for origin: SiteOrigin) -> Bool {
        (try? CrestCore.answer(SecureOriginCheck(origin: origin)))?.allowed ?? false
    }

    /// What a notification permission request leads to. An unavailable core denies it.
    static func hostedNotificationPermissionRequestAction(
        for decision: SitePermissionDecision,
        hasUserActivation: Bool
    ) -> HostedNotificationRequestAction {
        let question = NotificationPermissionRequest(decision: decision, hasUserActivation: hasUserActivation)
        return (try? CrestCore.answer(question))?.action ?? .respondDenied
    }

    /// The page's popup state after one event, or nil when nothing changes or
    /// the core cannot answer; the caller then keeps its state and shows no
    /// new indication.
    static func blockedPopupState(
        after event: BlockedPopupEvent, from state: BrowserBlockedPopupPageState,
        documentIdentifier: String? = nil, origin: SiteOrigin? = nil
    ) -> BrowserBlockedPopupPageState? {
        let current = BlockedPopupPageState(
            status: state.notice?.status, origin: state.notice?.origin,
            documentIdentifier: nonEmpty(state.documentIdentifier), indicationRevision: state.indicationRevision)
        let question = BlockedPopupTransition(
            state: current, event: event, documentIdentifier: nonEmpty(documentIdentifier), origin: origin)
        guard let next = (try? CrestCore.answer(question))?.state else { return nil }
        var notice: BrowserBlockedPopupNotice?
        if let status = next.status, let origin = next.origin {
            notice = BrowserBlockedPopupNotice(origin: origin, status: status)
        }
        return BrowserBlockedPopupPageState(
            notice: notice, documentIdentifier: next.documentIdentifier,
            indicationRevision: next.indicationRevision)
    }

    // MARK: - Actions - Downloads

    /// The automatic-download action and the page/origin throttle state to
    /// keep. An unavailable core asks the person instead of deciding silently.
    static func automaticDownload(
        isUserInitiated: Bool, isUserApprovedRetry: Bool,
        savedDecision: SitePermissionDecision, hasAllowedAutomaticDownload: Bool
    ) -> (action: AutomaticDownloadAction, hasAllowedAutomaticDownload: Bool) {
        let question = AutomaticDownloadCheck(
            userInitiated: isUserInitiated, userApprovedRetry: isUserApprovedRetry, savedDecision: savedDecision,
            hasAllowedAutomaticDownload: hasAllowedAutomaticDownload)
        guard let verdict = try? CrestCore.answer(question) else {
            return (.requestPermission, hasAllowedAutomaticDownload)
        }
        return (verdict.action, verdict.hasAllowedAutomaticDownload)
    }
}
