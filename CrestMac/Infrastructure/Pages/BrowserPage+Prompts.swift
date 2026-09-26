import Foundation

/// The questions the core asks about the page, shown as sheets on its window
/// whichever engine hosts it, with the person's answers sent back to the core.
extension BrowserPage: BrowserPromptPresenting {
    // MARK: - Actions - Prompts

    func ask(_ asked: ScriptDialogAsked, dismissal: BrowserPromptDismissal) {
        let question = asked.question
        let request = URLRequest(url: URL(string: question.sourceURL) ?? pageEngine.currentURL ?? URL(fileURLWithPath: "/"))
        let corePage = corePage
        let promptID = asked.promptID
        let reply: @MainActor @Sendable (Bool, String?) -> Void = { accepted, text in
            corePage.answer(AnswerScriptDialog(promptID: promptID, accepted: accepted, text: text))
        }
        switch question.kind {
        case .alert:
            dialogPresenter.presentAlert(message: question.message, request: request, dismissal: dismissal) {
                reply(true, nil)
            }
        case .confirm:
            dialogPresenter.presentConfirm(message: question.message, request: request, dismissal: dismissal) {
                reply($0, nil)
            }
        case .prompt:
            dialogPresenter.presentPrompt(
                message: question.message, defaultText: question.defaultText, request: request, dismissal: dismissal
            ) { answer in
                reply(answer != nil, answer)
            }
        case .beforeUnload:
            dialogPresenter.presentBeforeUnload(request: request, dismissal: dismissal) {
                reply($0, nil)
            }
        }
    }

    func ask(_ asked: AuthenticationAsked, dismissal: BrowserPromptDismissal) {
        let corePage = corePage
        let promptID = asked.promptID
        guard let challenge = BrowserAuthenticationChallenge(asked.question) else {
            corePage.answer(AnswerAuthentication(promptID: promptID, credential: nil))
            return
        }
        let session = httpAuthenticationSession
        let presenter = dialogPresenter
        let spaceName = spaceName
        Task { @MainActor in
            let decision = await session.response(to: challenge) { prompt in
                await presenter.presentHTTPAuthentication(prompt: prompt, spaceName: spaceName, dismissal: dismissal)
            }
            corePage.answer(AnswerAuthentication(promptID: promptID, credential: decision.credential))
        }
    }

    func ask(_ asked: PermissionAsked, dismissal: BrowserPromptDismissal) {
        let question = asked.question
        let corePage = corePage
        let promptID = asked.promptID
        let requests = sitePermissionRequests
        let spaceName = spaceName
        Task { @MainActor [weak self] in
            var response = await requests.response(
                to: question.permission, origin: question.origin, topLevelOrigin: question.topLevelOrigin,
                spaceName: spaceName, dismissal: dismissal)
            // An Allow the system then refuses saves nothing, so the site
            // cannot gain the capability silently once the system allows it.
            if response.grants, await self?.systemConsents(to: question.permission) != true {
                response = .denyOnce
            }
            corePage.answer(
                AnswerPermission(promptID: promptID, grants: response.grants, remembers: response.savedDecision != nil))
        }
    }

    /// Whether the system lets the site have `permission` the person allowed,
    /// asking them when it has not decided. WebKit's location and
    /// notifications ask here; capture, and what another engine asks the
    /// system for itself, pass.
    private func systemConsents(to permission: SitePermission) async -> Bool {
        guard let webKitAdapter else { return true }
        switch permission {
        case .location: return await webKitAdapter.geolocationCoordinator?.systemAuthorizes() ?? true
        case .notifications: return await authorizedForSystemNotifications(requestIfNeeded: true)
        default: return true
        }
    }
}
