import Foundation

/// Decides which of an extension's two package downloads is the one used.
///
/// Both report from whatever thread they run on, and exactly one outcome is
/// ever produced: the first package that is accepted, or a failure once no
/// download can still deliver one. The waiting caller is resumed once, by that
/// outcome. A package that arrives after the outcome is deleted here, so no
/// path leaves a file behind.
final class ExtensionPackageRace: @unchecked Sendable {
    enum Source: String, Sendable {
        case engine
        case urlSession = "urlsession"
    }
    struct Win: Sendable {
        let package: URL
        let source: Source
    }
    private let lock = NSLock()
    private var outcome: Result<Win, Error>?
    private var continuation: CheckedContinuation<Win, Error>?
    private var engineSpoke = false
    /// The engine's message once its download failed, which may be empty.
    private var engineFailure: String?
    /// Whether the engine could not even begin the download.
    private var engineUnavailable = false
    private var fallbackStarted = false
    private var fallbackFailure: String?

    func wait() async throws -> Win {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let decided = lock.withLock { () -> Result<Win, Error>? in
                    if outcome == nil { self.continuation = continuation }
                    return outcome
                }
                if let decided { continuation.resume(with: decided) }
            }
        } onCancel: {
            abort(CancellationError())
        }
    }
    /// Ends the race with `result` unless it has already ended.
    private func settle(_ result: Result<Win, Error>) -> Bool {
        let (first, waiting) = lock.withLock { () -> (Bool, CheckedContinuation<Win, Error>?) in
            guard outcome == nil else { return (false, nil) }
            outcome = result
            defer { continuation = nil }
            return (true, continuation)
        }
        waiting?.resume(with: result)
        return first
    }
    /// Whether `package` won. A package that did not is deleted.
    func offer(_ package: URL, from source: Source) -> Bool {
        if settle(.success(Win(package: package, source: source))) { return true }
        try? FileManager.default.removeItem(at: package)
        return false
    }
    func abort(_ error: Error) { _ = settle(.failure(error)) }

    func engineReportedProgress() { lock.withLock { engineSpoke = true } }
    func engineFinished(package: String?, message: String, unavailable: Bool = false) {
        lock.withLock { engineSpoke = true }
        if let package {
            _ = offer(URL(fileURLWithPath: package), from: .engine)
            return
        }
        let failure = lock.withLock { () -> Error? in
            engineFailure = message
            engineUnavailable = unavailable
            return fallbackStarted && fallbackFailure == nil ? nil : combinedFailure()
        }
        if let failure { abort(failure) }
    }
    /// Claims the second download. False when the race has ended, the engine
    /// has already reported, or the second download was already claimed.
    func beginFallback() -> Bool {
        lock.withLock {
            guard outcome == nil, !engineSpoke, !fallbackStarted else { return false }
            fallbackStarted = true
            return true
        }
    }
    /// Records the second download's failure. True while the race is still
    /// open, so the caller says so; the race ends here when the engine's
    /// download has failed too.
    func fallbackFailed(_ reason: String) -> Bool {
        let (open, failure) = lock.withLock { () -> (Bool, Error?) in
            fallbackFailure = reason
            return (outcome == nil, engineFailure == nil ? nil : combinedFailure())
        }
        if let failure { abort(failure) }
        return open
    }
    /// The engine's message when it has one, else the second download's reason.
    /// Called with the lock held.
    private func combinedFailure() -> Error {
        let reason = [engineFailure, fallbackStarted ? fallbackFailure : nil].compactMap { $0 }.first { !$0.isEmpty }
        return NSError(
            domain: "CrestExtension", code: 2,
            userInfo: [
                NSLocalizedDescriptionKey: reason.map {
                    String(localized: "Couldn’t download this extension from the Chrome Web Store (\($0)).")
                }
                    ?? (engineUnavailable
                        ? String(localized: "The Space is no longer available.")
                        : String(localized: "Couldn’t download this extension from the Chrome Web Store."))
            ])
    }
}
