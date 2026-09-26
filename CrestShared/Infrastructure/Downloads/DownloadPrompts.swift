import Foundation

/// Answers the questions the core asks about the downloads engines run,
/// whichever engine runs them: where each file goes, and whether to keep one
/// its engine warned about. One follows each core.
@MainActor
final class BrowserDownloadPrompts {
    // MARK: - Types

    /// Asks the person whether to keep the download `asked` is about, until
    /// the dismissal closes the question.
    typealias Approve = @MainActor (_ asked: DownloadApprovalAsked, _ dismissal: BrowserPromptDismissal) async -> Bool

    // MARK: - Variables

    private weak var core: CrestCore?
    private let approve: Approve
    private let resolveDestination: BrowserDownloadCenter.DownloadDestinationResolver
    /// What closes each approval the person is shown, until the core settles it.
    private var dismissals: [UUID: BrowserPromptDismissal] = [:]
    /// The folder access each download writing into a chosen folder holds
    /// until it ends.
    private var downloadFolders: [UUID: URL] = [:]

    // MARK: - Initializers

    /// Answers `core`'s download questions, asking the person with `approve`
    /// and choosing each file's place with `resolveDestination`.
    init(
        core: CrestCore,
        approve: @escaping Approve,
        resolveDestination: @escaping BrowserDownloadCenter.DownloadDestinationResolver = {
            await BrowserPlatformDownloadDirectory.resolve(suggestedFilename: $0, spaceID: $1, forcesPrompt: $2)
        }
    ) {
        self.core = core
        self.approve = approve
        self.resolveDestination = resolveDestination
        core.followPrompts(self) { [weak self] change in self?.ask(change) }
        core.followDownloads(self) { [weak self] download in
            guard !download.phase.isLive else { return }
            self?.downloadFolders.removeValue(forKey: download.id)?.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Actions - Prompts

    /// Answers a question the core asks about a download, and closes an
    /// approval once the core settles it.
    private func ask(_ change: Change) {
        switch change {
        case .downloadDestinationAsked(let asked):
            choose(asked)
        case .downloadApprovalAsked(let asked):
            let dismissal = BrowserPromptDismissal()
            dismissals[asked.promptID] = dismissal
            Task { @MainActor [weak self, approve] in
                let approved = await approve(asked, dismissal)
                self?.answer(AnswerDownloadApproval(promptID: asked.promptID, approved: approved))
            }
        case .promptSettled(let settled):
            dismissals.removeValue(forKey: settled.promptID)?.dismiss()
        default:
            break
        }
    }

    /// Where a download's file goes: the Space's download folder, or where
    /// the person chooses when the Space or the engine asks for that.
    private func choose(_ asked: DownloadDestinationAsked) {
        Task { @MainActor [weak self, resolveDestination] in
            let resolution = await resolveDestination(asked.suggestedFilename, asked.spaceID, asked.forcesPrompt)
            guard let self else {
                if case .destination(_, let scoped) = resolution { scoped?.stopAccessingSecurityScopedResource() }
                return
            }
            switch resolution {
            case .destination(let url, let scoped):
                if let scoped { downloadFolders[asked.downloadID] = scoped }
                answer(AnswerDownloadDestination(promptID: asked.promptID, path: url.path))
            case .cancelled:
                answer(AnswerDownloadDestination(promptID: asked.promptID, path: nil))
            case .unavailable:
                _ = try? core?.send(
                    FailDownload(downloadID: asked.downloadID, reason: .folderUnavailable, message: nil))
                answer(AnswerDownloadDestination(promptID: asked.promptID, path: nil))
            }
        }
    }

    /// Sends the person's answer to a question the core asked. An answer to a
    /// question that no longer waits changes nothing.
    private func answer(_ intent: some PromptIntent) {
        _ = try? core?.send(intent)
    }
}
