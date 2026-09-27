import AppKit
import Foundation
import WebKit

extension BrowserPage {
    /// The bridge's per-document state lives with the WebKit adapter; another
    /// engine never posts through this bridge.
    var hostedNotificationDocumentIdentifier: String {
        get { webKitAdapter?.hostedNotificationDocumentIdentifier ?? "" }
        set { webKitAdapter?.hostedNotificationDocumentIdentifier = newValue }
    }

    /// Follows a change to the site's notification decision: the document is
    /// told the permission it now has. The page has already taken down what
    /// it may no longer show.
    func refreshHostedWebNotificationPermission() {
        guard let currentURL = live.displayURL ?? webKitView?.url,
            let origin = SiteOrigin(url: currentURL)
        else {
            return
        }
        let documentIdentifier = hostedNotificationDocumentIdentifier
        Task { @MainActor [weak self] in
            await self?.sendHostedNotificationPermission(
                requestID: "site-controls",
                origin: origin,
                requestsSystemAuthorization: false,
                documentIdentifier: documentIdentifier,
                frame: nil
            )
        }
    }

    func receiveHostedWebNotificationMessage(_ message: WKScriptMessage) {
        if let sourceWebView = message.webView, sourceWebView !== webKitView {
            host?.routeHostedWebNotificationMessage(message)
            return
        }
        guard hostedNotificationCenter != nil,
            message.webView === webKitView,
            message.frameInfo.isMainFrame,
            let requestURL = message.frameInfo.request.url,
            let origin = SiteOrigin(url: requestURL),
            SiteOrigin(message.frameInfo.securityOrigin) == origin,
            BrowserCorePolicy.allowsHostedNotifications(for: origin),
            let body = message.body as? [String: Any],
            (body["version"] as? Int) == 1,
            let action = body["action"] as? String
        else { return }
        let documentIdentifier = hostedNotificationDocumentIdentifier

        switch action {
        case "queryPermission":
            guard let requestID = body["requestID"] as? String,
                isValidHostedWebNotificationIdentifier(requestID)
            else { return }
            Task { @MainActor [weak self] in
                await self?.sendHostedNotificationPermission(
                    requestID: requestID,
                    origin: origin,
                    requestsSystemAuthorization: false,
                    documentIdentifier: documentIdentifier,
                    frame: message.frameInfo
                )
            }
        case "requestPermission":
            guard let requestID = body["requestID"] as? String,
                isValidHostedWebNotificationIdentifier(requestID)
            else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let userActivation = await hasActiveUserGesture(in: message.frameInfo)
                await resolveHostedNotificationPermission(
                    requestID: requestID,
                    origin: origin,
                    hasUserActivation: userActivation,
                    documentIdentifier: documentIdentifier,
                    frame: message.frameInfo
                )
            }
        case "create":
            guard let identifier = body["identifier"] as? String,
                isValidHostedWebNotificationIdentifier(identifier),
                let title = body["title"] as? String,
                let notificationBody = body["body"] as? String
            else { return }
            let isSilent = body["silent"] as? Bool ?? false
            Task { @MainActor [weak self] in
                await self?.createHostedWebNotification(
                    identifier: identifier,
                    title: title,
                    body: notificationBody,
                    isSilent: isSilent,
                    origin: origin,
                    documentIdentifier: documentIdentifier
                )
            }
        case "close":
            guard let identifier = body["identifier"] as? String,
                isValidHostedWebNotificationIdentifier(identifier)
            else { return }
            withdrawWebNotification(hostedSystemIdentifier(for: identifier))
        default:
            return
        }
    }

    func beginHostedWebNotificationNavigation() {
        sitePermissionRequests.cancelAll()
        removeWebNotifications()
        hostedNotificationDocumentIdentifier = UUID().uuidString
    }

    private func resolveHostedNotificationPermission(
        requestID: String,
        origin: SiteOrigin,
        hasUserActivation: Bool,
        documentIdentifier: String,
        frame: WKFrameInfo
    ) async {
        guard
            isCurrentHostedNotificationDocument(
                documentIdentifier,
                origin: origin
            )
        else { return }
        let decision = permissionCenter.decision(
            for: .notifications,
            origin: origin,
            in: spaceID
        )
        switch BrowserCorePolicy.hostedNotificationPermissionRequestAction(
            for: decision,
            hasUserActivation: hasUserActivation
        ).kind {
        case .respondDenied:
            sendHostedNotificationPermissionResponse(
                requestID: requestID,
                permission: "denied",
                documentIdentifier: documentIdentifier,
                origin: origin,
                frame: frame
            )
        case .resolveSystemAuthorization:
            await sendHostedNotificationPermission(
                requestID: requestID,
                origin: origin,
                requestsSystemAuthorization: hasUserActivation,
                documentIdentifier: documentIdentifier,
                frame: frame
            )
        case .respondDefault:
            sendHostedNotificationPermissionResponse(
                requestID: requestID,
                permission: "default",
                documentIdentifier: documentIdentifier,
                origin: origin,
                frame: frame
            )
        case .promptForSitePermission:
            let generation = sitePermissionRequests.generation
            // The core asks the person and records what they ask it to
            // remember; the system's consent still decides what the page hears.
            let grants =
                await webKitAdapter?.webKitPage.ask(
                    PermissionQuestion(permission: .notifications, origin: origin, topLevelOrigin: origin)) ?? false
            guard
                isCurrentHostedNotificationDocument(
                    documentIdentifier,
                    origin: origin
                )
            else { return }
            guard generation == sitePermissionRequests.generation else { return }
            guard grants else {
                // A block the person asked the core to remember denies the
                // site; a decline that saves nothing leaves it free to ask.
                let denies = permissionCenter.decision(for: .notifications, origin: origin, in: spaceID).denies
                sendHostedNotificationPermissionResponse(
                    requestID: requestID, permission: denies ? "denied" : "default",
                    documentIdentifier: documentIdentifier, origin: origin, frame: frame
                )
                return
            }
            guard await authorizedForSystemNotifications(requestIfNeeded: true) else {
                sendHostedNotificationPermissionResponse(
                    requestID: requestID,
                    permission: "denied",
                    documentIdentifier: documentIdentifier,
                    origin: origin,
                    frame: frame
                )
                return
            }
            guard
                isCurrentHostedNotificationDocument(
                    documentIdentifier,
                    origin: origin
                )
            else { return }
            guard generation == sitePermissionRequests.generation else {
                await sendHostedNotificationPermission(
                    requestID: requestID, origin: origin,
                    requestsSystemAuthorization: false,
                    documentIdentifier: documentIdentifier, frame: frame
                )
                return
            }
            guard !permissionCenter.decision(for: .notifications, origin: origin, in: spaceID).denies else {
                sendHostedNotificationPermissionResponse(
                    requestID: requestID, permission: "denied",
                    documentIdentifier: documentIdentifier, origin: origin, frame: frame
                )
                return
            }
            // A granted request is remembered for the session at least; a
            // grant the person asked the core to remember is already kept.
            if !permissionCenter.decision(for: .notifications, origin: origin, in: spaceID).grants {
                permissionCenter.setDecision(.grantForSession, for: .notifications, origin: origin, in: spaceID)
            }
            sendHostedNotificationPermissionResponse(
                requestID: requestID,
                permission: "granted",
                documentIdentifier: documentIdentifier,
                origin: origin,
                frame: frame
            )
        }
    }

    private func sendHostedNotificationPermission(
        requestID: String,
        origin: SiteOrigin,
        requestsSystemAuthorization: Bool,
        documentIdentifier: String,
        frame: WKFrameInfo?
    ) async {
        guard
            isCurrentHostedNotificationDocument(
                documentIdentifier,
                origin: origin
            )
        else { return }
        let siteDecision = permissionCenter.decision(
            for: .notifications,
            origin: origin,
            in: spaceID
        )
        // The states are the Notifications API's.
        let permission: String
        switch siteDecision.verdict {
        case .deny:
            permission = "denied"
        case .ask:
            permission = "default"
        case .grant:
            guard let hostedNotificationCenter else {
                permission = "denied"
                break
            }
            if requestsSystemAuthorization {
                permission =
                    await authorizedForSystemNotifications(
                        requestIfNeeded: true
                    )
                    ? "granted" : "denied"
            } else {
                switch await hostedNotificationCenter.currentAuthorization() {
                case .authorized:
                    permission = "granted"
                case .denied:
                    permission = "denied"
                case .notDetermined:
                    permission = "default"
                }
            }
        }
        guard
            isCurrentHostedNotificationDocument(
                documentIdentifier,
                origin: origin
            )
        else { return }
        sendHostedNotificationPermissionResponse(
            requestID: requestID,
            permission: permission,
            documentIdentifier: documentIdentifier,
            origin: origin,
            frame: frame
        )
    }

    /// Shows what the document posted through Crest's shared path, and tells
    /// the document whether it shows and when the person clicks it.
    private func createHostedWebNotification(
        identifier: String,
        title: String,
        body: String,
        isSilent: Bool,
        origin: SiteOrigin,
        documentIdentifier: String
    ) async {
        let shown = await showWebNotification(
            BrowserHostedWebNotificationDelivery(
                identifier: "\(documentIdentifier).\(identifier)",
                title: title,
                body: body,
                origin: origin,
                isSilent: isSilent
            ),
            isPosted: { [weak self] in
                self?.isCurrentHostedNotificationDocument(documentIdentifier, origin: origin) ?? false
            },
            clicked: { [weak self] in
                self?.sendHostedNotificationEvent(
                    identifier: identifier,
                    event: "click",
                    documentIdentifier: documentIdentifier,
                    origin: origin
                )
            }
        )
        sendHostedNotificationEvent(
            identifier: identifier,
            event: shown ? "show" : "error",
            documentIdentifier: documentIdentifier,
            origin: origin
        )
    }

    /// Whether the system lets Crest show notifications, offering to recover
    /// a refusal and, when `requestIfNeeded`, asking the person when it has
    /// not decided.
    func authorizedForSystemNotifications(
        requestIfNeeded: Bool
    ) async -> Bool {
        guard let hostedNotificationCenter else { return false }
        switch await hostedNotificationCenter.currentAuthorization() {
        case .authorized:
            return true
        case .denied:
            await recoverNotificationSystemAuthorization()
            return await hostedNotificationCenter.currentAuthorization()
                == .authorized
        case .notDetermined:
            guard requestIfNeeded else { return false }
            return await hostedNotificationCenter.requestAuthorization() == .authorized
        }
    }

    private func hasActiveUserGesture(in frame: WKFrameInfo) async -> Bool {
        guard let webView = webKitView else { return false }
        let result = try? await webView.callAsyncJavaScript(
            "return navigator.userActivation?.isActive === true;",
            arguments: [:],
            in: frame,
            contentWorld: .page
        )
        return result as? Bool ?? false
    }

    private func hostedSystemIdentifier(for identifier: String) -> String {
        "\(hostedNotificationDocumentIdentifier).\(identifier)"
    }

    private func isValidHostedWebNotificationIdentifier(
        _ identifier: String
    ) -> Bool {
        !identifier.isEmpty && identifier.utf8.count <= 128
    }

    private func sendHostedNotificationPermissionResponse(
        requestID: String,
        permission: String,
        documentIdentifier: String,
        origin: SiteOrigin,
        frame: WKFrameInfo?
    ) {
        sendHostedNotificationMessage(
            [
                "type": "permission",
                "requestID": requestID,
                "permission": permission,
            ],
            documentIdentifier: documentIdentifier,
            origin: origin,
            frame: frame
        )
    }

    private func sendHostedNotificationEvent(
        identifier: String,
        event: String,
        documentIdentifier: String,
        origin: SiteOrigin
    ) {
        sendHostedNotificationMessage(
            [
                "type": "event",
                "identifier": identifier,
                "event": event,
            ],
            documentIdentifier: documentIdentifier,
            origin: origin,
            frame: nil
        )
    }

    private func sendHostedNotificationMessage(
        _ message: [String: Any],
        documentIdentifier: String,
        origin: SiteOrigin,
        frame: WKFrameInfo?
    ) {
        guard
            isCurrentHostedNotificationDocument(
                documentIdentifier,
                origin: origin
            )
        else { return }
        let webView = webKitView
        Task { @MainActor [weak self, weak webView] in
            guard let self,
                isCurrentHostedNotificationDocument(
                    documentIdentifier,
                    origin: origin
                )
            else { return }
            _ = try? await webView?.callAsyncJavaScript(
                "globalThis.__crestHostedNotificationBridge?.receive(message);",
                arguments: ["message": message],
                in: frame,
                contentWorld: .page
            )
        }
    }

    private func isCurrentHostedNotificationDocument(
        _ documentIdentifier: String,
        origin: SiteOrigin
    ) -> Bool {
        guard documentIdentifier == hostedNotificationDocumentIdentifier,
            let currentURL = webKitView?.url ?? live.displayURL,
            let currentOrigin = SiteOrigin(url: currentURL)
        else { return false }
        return currentOrigin == origin
    }
}
