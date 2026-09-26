#if CREST_CHROMIUM_HOST
    import Foundation

    /// Shows the engine's downloads in the download center of the Space each
    /// belongs to, and answers where each one's file goes. TRANSITIONAL until
    /// downloads move to the core (WP C (f)).
    @MainActor
    final class ChromiumDownloadAdapter: BrowserEngineDownloadControlling {
        struct Destination {
            let center: BrowserDownloadCenter
            let assignment: BrowserSpaceRuntimeAssignment
        }
        private let engine: ChromiumEngine
        private let resolve: (EngineDownload) -> Destination?
        private struct CachedDestination {
            weak var center: BrowserDownloadCenter?
            let assignment: BrowserSpaceRuntimeAssignment
        }
        private var destinations: [BrowserEngineDownloadID: CachedDestination] = [:]

        init(engine: ChromiumEngine, resolve: @escaping (EngineDownload) -> Destination?) {
            self.engine = engine
            self.resolve = resolve
        }

        /// Where the download the engine asks about goes: its Space's download
        /// center decides, asking the person when the engine says to.
        func resolveDestination(_ request: EngineDownloadDestinationRequested) {
            guard let (id, destination) = receive(request.download) else {
                answer(request, path: nil)
                return
            }
            Task { @MainActor in
                let url = await destination.center.resolveEngineDownloadDestination(
                    id, suggestedFilename: request.suggestedFilename, forcesPrompt: request.forcesPrompt)
                answer(request, path: url?.path)
            }
        }

        private func answer(_ request: EngineDownloadDestinationRequested, path: String?) {
            engine.pages.request(AnswerEngineDownloadDestination(requestID: request.requestID, path: path))
        }

        @discardableResult
        func receive(_ download: EngineDownload) -> (BrowserEngineDownloadID, Destination)? {
            let id = BrowserEngineDownloadID(
                engine: .chromium, profileID: download.profileID, value: download.downloadID)
            let target: Destination?
            if let cached = destinations[id] {
                target = cached.center.map { Destination(center: $0, assignment: cached.assignment) }
            } else {
                target = resolve(download)
            }
            guard let destination = target else {
                cancelDownload(id)
                return nil
            }
            destinations[id] = CachedDestination(center: destination.center, assignment: destination.assignment)
            let state: BrowserEngineDownloadUpdate.State
            switch download.state {
            case .finished: state = .finished
            case .canceled: state = .canceled
            case .failed:
                state = .failed(
                    download.failure ?? download.warning.map(Self.message)
                        ?? String(localized: "The download failed."))
            case .awaitingApproval:
                guard let warning = download.warning else {
                    cancelDownload(id)
                    return nil
                }
                state = .awaitingApproval(token: download.approvalToken, message: Self.message(for: warning))
            case .downloading: state = .downloading
            case .preparing: state = .preparing
            }
            destination.center.receiveEngineDownload(
                BrowserEngineDownloadUpdate(
                    id: id,
                    filename: download.filename.isEmpty ? "download" : download.filename,
                    destination: download.path.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) },
                    bytesReceived: download.received,
                    totalBytes: download.total,
                    isPaused: download.paused, state: state,
                    // The core only records finite dates.
                    createdAt: download.startedAt.timeIntervalSinceReferenceDate.isFinite ? download.startedAt : .now,
                    isRestored: download.restored),
                assignment: destination.assignment, controller: self)
            return (id, destination)
        }

        /// What the person is told about a download the engine warned about or
        /// blocked.
        private static func message(for warning: EngineDownloadWarning) -> String {
            switch warning {
            case .insecureConnection:
                String(
                    localized:
                        "This file was transferred over an insecure connection and could have been changed by someone else. Keep it only if you trust its source."
                )
            case .dangerousFile:
                String(localized: "This type of file can change your computer. Keep it only if you trust its source.")
            case .uncommonContent:
                String(localized: "This file is not commonly downloaded. The engine could not confirm that it is safe.")
            case .potentiallyUnwanted:
                String(localized: "This file may change your browser or computer settings without your permission.")
            case .insecureBlocked:
                String(localized: "The engine blocked this insecure download.")
            case .policyBlocked:
                String(
                    localized:
                        "The engine blocked this download because of its safety or organization policy verdict.")
            }
        }

        func cancelDownload(_ id: BrowserEngineDownloadID) {
            guard id.engine == .chromium else { return }
            engine.pages.request(CancelEngineDownload(profileID: id.profileID, downloadID: id.value))
        }
        func removeDownload(_ id: BrowserEngineDownloadID) {
            guard id.engine == .chromium else { return }
            engine.pages.request(RemoveEngineDownload(profileID: id.profileID, downloadID: id.value))
        }
        func approveDownload(_ id: BrowserEngineDownloadID, warningToken: String) {
            guard id.engine == .chromium else { return }
            engine.pages.request(
                ApproveEngineDownload(profileID: id.profileID, downloadID: id.value, approvalToken: warningToken))
        }
    }
#endif
