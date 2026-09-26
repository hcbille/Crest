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
}

