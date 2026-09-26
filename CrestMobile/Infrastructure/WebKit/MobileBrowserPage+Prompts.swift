import Foundation

/// The questions the core asks about the page, shown as alerts over the
/// window, with the person's answers sent back to the core.
extension MobileBrowserPage: BrowserPromptPresenting {
    // MARK: - Actions - Prompts

    func ask(_ asked: ScriptDialogAsked, dismissal: BrowserPromptDismissal) {
        let question = asked.question
        let request = URLRequest(url: URL(string: question.sourceURL) ?? webView.url ?? URL(fileURLWithPath: "/"))
        let corePage = corePage
        let promptID = asked.promptID
        let reply: @MainActor @Sendable (Bool, String?) -> Void = { accepted, text in
            corePage.answer(AnswerScriptDialog(promptID: promptID, accepted: accepted, text: text))
        }
        switch question.kind {
        case .alert:
            MobileBrowserDialogPresenter.presentAlert(message: question.message, request: request, dismissal: dismissal) {
                reply(true, nil)
            }
        case .confirm, .beforeUnload:
            MobileBrowserDialogPresenter.presentConfirmation(
                message: question.message, request: request, dismissal: dismissal
            ) {
                reply($0, nil)
            }
        case .prompt:
            MobileBrowserDialogPresenter.presentPrompt(
                message: question.message, defaultText: question.defaultText, request: request, dismissal: dismissal
            ) { answer in
                reply(answer != nil, answer)
            }
        }
    }
}
