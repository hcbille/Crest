import Foundation

/// Prepares a quit through the core, for either engine's composition: the core
/// asks every page whether it may go, then asks the person whether to stop the
/// downloads still in progress, which this shows as an alert on the key window.
@MainActor
final class BrowserQuitPreparation {
    // MARK: - Variables

    private weak var core: CrestCore?
    private let dialogs = BrowserDialogPresenter()
    /// How to close the question about downloads in progress, while it waits.
    private var dismissals: [UUID: BrowserPromptDismissal] = [:]

    // MARK: - Initializers

    init(core: CrestCore) {
        self.core = core
        core.followChanges(self)
    }

    // MARK: - Actions - Quitting

    /// Asks the core whether the app may quit, and calls `completion` with the
    /// answer on a later turn of the main actor.
    func prepare(completion: @escaping @MainActor (Bool) -> Void) {
        guard let core else {
            Task { @MainActor in completion(false) }
            return
        }
        core.prepareToClose(PrepareToQuit(requestID: UUID())) { allowed in
            Task { @MainActor in completion(allowed) }
        }
    }
}

// MARK: - Prompts

/// Shows the question about downloads in progress, and closes it once the
/// core settles it. It observes only that question.
extension BrowserQuitPreparation: ChangeObserving {
    func handle(_ asked: QuitWithDownloadsAsked) {
        let dismissal = BrowserPromptDismissal()
        dismissals[asked.promptID] = dismissal
        Task { @MainActor [weak self] in
            guard let self else { return }
            let quits = await dialogs.approveQuitWithDownloads(count: asked.liveDownloads, dismissal: dismissal)
            _ = try? core?.send(AnswerQuitWithDownloads(promptID: asked.promptID, quits: quits))
        }
    }

    func handle(_ settled: PromptSettled) {
        dismissals.removeValue(forKey: settled.promptID)?.dismiss()
    }
}
