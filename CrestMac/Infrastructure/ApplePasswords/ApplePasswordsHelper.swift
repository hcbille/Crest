import Foundation

/// Owns the one Apple Passwords helper process for the whole launch, shared by
/// every Space: Crest pairs once per launch. Nothing here persists. The
/// session key, identifier and private exponent live in memory and are dropped
/// when the helper pushes a re-login request, a request goes unanswered, the
/// process ends, or Crest stops it.
@MainActor
final class ApplePasswordsHelper: ApplePasswordsCredentialSource {
    // MARK: - Types

    enum State: Equatable, Sendable {
        /// No helper process has been asked for.
        case stopped
        /// The helper cannot be used. This holds until `stop()`.
        case unavailable(ApplePasswordsUnavailability)
        /// The helper is understood but holds no session with Crest.
        case unpaired
        /// The helper shows a code and a challenge waits for it.
        case awaitingCode
        case paired
    }

    /// What a query needs from a paired helper, taken together so an answer
    /// can be checked against the session it was asked over.
    private struct Connection {
        let queue: ApplePasswordsRequestQueue
        let session: ApplePasswordsSecretSession
        let generation: Int
    }

    // MARK: - Static Variables

    private static let codeLength = 6

    // MARK: - Variables

    private(set) var state: State = .stopped {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }
    /// Called after every change of `state`.
    var onStateChange: (@MainActor (State) -> Void)?

    private let launcher: any ApplePasswordsChannelLauncher
    private let clock = ContinuousClock()
    private var capabilities: ApplePasswordsCapabilities?
    private var queue: ApplePasswordsRequestQueue?
    private var channel: (any ApplePasswordsChannel)?
    private var events: Task<Void, Never>?
    private var startup: Task<Void, Never>?
    private var attempt: ApplePasswordsPairingAttempt?
    private var session: ApplePasswordsSecretSession?
    private var tabIDs: [String: Int] = [:]
    /// Changes whenever the process or its session is replaced, so an answer
    /// that arrives for an earlier one is not applied to the new one.
    private var generation = 0
    /// Changes whenever pairing starts over, so a hello or proof that arrives
    /// for an earlier attempt is dropped instead of installing a session.
    private var pairingEpoch = 0

    // MARK: - Initializers

    init(launcher: any ApplePasswordsChannelLauncher) {
        self.launcher = launcher
    }

    // MARK: - Actions - Lifecycle

    /// Starts the helper and learns what it supports. Does nothing unless the
    /// core's answer for the Space starts the helper, or if the helper is
    /// running, or was found unusable.
    /// - Parameter support: The answer to `ApplePasswordsAvailability`.
    func start(support: ApplePasswordsSupport) async {
        guard support.status.startsHelper else { return }
        if let startup { return await startup.value }
        guard queue == nil, !isUnavailable else { return }
        let task = Task { await launchAndNegotiate() }
        startup = task
        await task.value
        startup = nil
    }

    /// Tells the helper Crest is done, ends it and forgets everything.
    func stop() {
        if channel != nil, let end = try? ApplePasswordsEndMessage.encoded() {
            try? channel?.send(end)
        }
        tearDown()
        state = .stopped
    }

    private func launchAndNegotiate() async {
        let launched: any ApplePasswordsChannel
        do {
            launched = try launcher.launch()
        } catch {
            fail(because: unavailability(of: error))
            return
        }
        let queue = ApplePasswordsRequestQueue(channel: launched)
        channel = launched
        self.queue = queue
        let current = generation
        listen(to: queue, generation: current)
        do {
            let reported = try await queue.submit(ApplePasswordsCapabilitiesRequest())
            guard current == generation else { return }
            guard reported.isRecognized else {
                fail(because: .unrecognizedCapabilities)
                return
            }
            capabilities = reported
            state = .unpaired
        } catch {
            settle(after: error, generation: current)
        }
    }

    // MARK: - Actions - Pairing

    /// Asks the helper to show a new six-digit code. Any earlier code stops working.
    func requestPairingCode(support: ApplePasswordsSupport) async throws {
        try require(support)
        await start(support: support)
        guard let queue, let capabilities else { throw unavailableError() }
        dropSession()
        state = .unpaired
        pairingEpoch += 1
        let current = generation
        let epoch = pairingEpoch
        do {
            let opening = try ApplePasswordsPairingAttempt.opening(byteEncoding: capabilities.byteEncoding)
            let hello = try await queue.submit(opening.request)
            guard current == generation, epoch == pairingEpoch else { throw ApplePasswordsError.cancelled }
            attempt = try ApplePasswordsPairingAttempt.answered(
                hello,
                client: opening.client,
                byteEncoding: capabilities.byteEncoding,
                at: clock.now
            )
            state = .awaitingCode
        } catch {
            if epoch == pairingEpoch { settle(after: error, generation: current) }
            throw error
        }
    }

    /// Proves the code the person typed. The challenge is spent whatever the
    /// outcome, so a wrong code needs a new one from `requestPairingCode()`.
    /// - Throws: `ApplePasswordsPairingError.wrongCode` for a code that does not match.
    func completePairing(code: String, support: ApplePasswordsSupport) async throws {
        try require(support)
        // A code that cannot be one is refused before the challenge is spent.
        guard code.count == Self.codeLength, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw ApplePasswordsPairingError.malformedCode
        }
        guard let queue else { throw unavailableError() }
        guard let challenge = attempt else { throw ApplePasswordsPairingError.challengeExpired }
        attempt = nil
        guard challenge.isLive(at: clock.now) else {
            state = .unpaired
            throw ApplePasswordsPairingError.challengeExpired
        }
        let current = generation
        let epoch = pairingEpoch
        do {
            let answer = try challenge.answer(code: code)
            let verification = try await queue.submit(answer.request)
            guard current == generation, epoch == pairingEpoch else { throw ApplePasswordsError.cancelled }
            guard answer.solution.verifies(serverProof: verification.proof) else {
                throw ApplePasswordsPairingError.serverProofMismatch
            }
            session = ApplePasswordsSecretSession(
                identity: challenge.identity,
                sharedKey: answer.solution.sessionKey,
                byteEncoding: challenge.byteEncoding
            )
            state = .paired
        } catch {
            if epoch == pairingEpoch { settle(after: error, generation: current) }
            throw error
        }
    }

    /// Gives up on the code the helper shows, as Apple's extension does when its
    /// pairing popup closes: tells the helper, then answers with an empty code so
    /// it spends the challenge. Does nothing unless a code is waiting.
    ///
    /// Both messages go straight to the channel and nothing waits for the
    /// refusal, so a silent helper cannot time the session out. The refusal,
    /// if it comes, carries the cancelled attempt's session identifier, and a
    /// pairing request ignores replies that carry another one.
    func cancelPairing() {
        guard state == .awaitingCode, let challenge = attempt, let channel else { return }
        attempt = nil
        pairingEpoch += 1
        state = .unpaired
        do {
            try channel.send(ApplePasswordsCancelPairingMessage.encoded())
            try channel.send(challenge.answer(code: "").request.encoded())
        } catch {
            fail(because: unavailability(of: error))
        }
    }

    // MARK: - Actions - Credentials

    func logins(
        for origin: CredentialOrigin,
        support: ApplePasswordsSupport
    ) async throws -> ApplePasswordsLoginNamesRequest.Logins {
        let host = try Self.host(of: origin)
        try requireOffer(support)
        let connection = try pairedConnection()
        let request = ApplePasswordsLoginNamesRequest(session: connection.session, tabID: tabID(for: host), host: host)
        return try await submit(request, over: connection)
    }

    func password(
        for origin: CredentialOrigin,
        username: String,
        support: ApplePasswordsSupport
    ) async throws -> String {
        let host = try Self.host(of: origin)
        try requireOffer(support)
        let connection = try pairedConnection()
        let request = ApplePasswordsPasswordRequest(
            session: connection.session,
            tabID: tabID(for: host),
            host: host,
            username: username
        )
        guard let password = try await submit(request, over: connection) else {
            throw ApplePasswordsError.loginNotFound
        }
        return password
    }

    /// Whether the helper said it can save an account with no username.
    var savesAccountsWithoutUsername: Bool {
        capabilities?.canSaveAccountWithEmptyUserName == true
    }

    /// Offers the account to Apple Passwords, which asks the person to confirm
    /// in its own alert. Create or update is the helper's decision. The result
    /// is "sent", not "saved": the helper may never acknowledge, so the request
    /// waits a few seconds and carries on with the session intact.
    ///
    /// The account is saved for the origin it was captured for, by its host,
    /// and only if the origin is https and the core's answer offers Apple
    /// Passwords. Both are checked before anything is sent. The password
    /// lives only as long as the request does.
    func save(
        _ username: String, _ password: String, for origin: CredentialOrigin, form: ApplePasswordsFormKind,
        support: ApplePasswordsSupport
    ) async throws {
        try requireOffer(support)
        _ = try Self.host(of: origin)
        let connection = try pairedConnection()
        let request = try Self.saveRequest(
            username: username, password: password, origin: origin, form: form, tabID: { self.tabID(for: $0) },
            session: connection.session)
        try await submit(request, over: connection)
    }

    /// The request that offers `username` and `password` for the origin's host.
    /// Throws for an origin that is not https.
    static func saveRequest(
        username: String, password: String, origin: CredentialOrigin, form: ApplePasswordsFormKind,
        tabID: (String) -> Int, session: ApplePasswordsSecretSession
    ) throws -> ApplePasswordsSaveRequest {
        let host = try host(of: origin)
        return ApplePasswordsSaveRequest(
            session: session, tabID: tabID(host), host: host, username: username, password: password, form: form)
    }

    private func submit<Request: ApplePasswordsRequest>(
        _ request: Request,
        over connection: Connection
    ) async throws -> Request.Reply {
        do {
            return try await connection.queue.submit(request)
        } catch {
            settle(after: error, generation: connection.generation)
            throw error
        }
    }

    // MARK: - Actions - Connection

    private func pairedConnection() throws -> Connection {
        if case .unavailable(let reason) = state { throw ApplePasswordsError.unavailable(reason) }
        guard let queue, let session, state == .paired else { throw ApplePasswordsError.notPaired }
        return Connection(queue: queue, session: session, generation: generation)
    }

    /// The host a query is about. Only https origins are queried, and only by host.
    private static func host(of origin: CredentialOrigin) throws -> String {
        guard origin.isSecure else { throw ApplePasswordsError.insecureOrigin }
        return origin.host
    }

    /// Reading logins is gated by the stronger answer: Apple Passwords is on offer in the Space.
    private func requireOffer(_ support: ApplePasswordsSupport) throws {
        guard support.status.offersApplePasswords else { throw ApplePasswordsError.notPermitted }
    }

    /// Starting and pairing are gated by the core's answer for the Space.
    private func require(_ support: ApplePasswordsSupport) throws {
        guard support.status.startsHelper else { throw ApplePasswordsError.notPermitted }
    }

    private func tabID(for host: String) -> Int {
        if let existing = tabIDs[host] { return existing }
        let next = tabIDs.count + 1
        tabIDs[host] = next
        return next
    }

    // MARK: - Mutators

    private var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }

    private func unavailableError() -> ApplePasswordsError {
        if case .unavailable(let reason) = state { return .unavailable(reason) }
        return .notPaired
    }

    private func unavailability(of error: any Error) -> ApplePasswordsUnavailability {
        if let unavailability = error as? ApplePasswordsUnavailability { return unavailability }
        if case .unavailable(let reason)? = error as? ApplePasswordsError { return reason }
        return .malformedReply
    }

    /// Forgets the session and any challenge. The process, if any, stays.
    private func dropSession() {
        session = nil
        attempt = nil
    }

    /// Ends the process and forgets everything it was paired with.
    private func tearDown() {
        generation += 1
        dropSession()
        capabilities = nil
        tabIDs = [:]
        events?.cancel()
        events = nil
        channel?.terminate()
        channel = nil
        if let queue { Task { await queue.shutdown() } }
        queue = nil
    }

    private func fail(because reason: ApplePasswordsUnavailability) {
        DiagnosticLog.applePasswords.notice("The helper is unavailable.")
        tearDown()
        state = .unavailable(reason)
    }

    /// Brings `state` in line with a failed call, unless the process or session has since changed.
    private func settle(after error: any Error, generation callGeneration: Int) {
        guard callGeneration == generation else { return }
        if error is ApplePasswordsPairingError {
            dropSession()
            state = .unpaired
            return
        }
        guard let error = error as? ApplePasswordsError else { return }
        switch error {
        case .unavailable(.timedOut):
            // The queue gave up on a request: end the session rather than risk a mismatched reply.
            tearDown()
            state = .unpaired
        case .unavailable(let reason):
            fail(because: reason)
        case .notPaired, .malformedReply:
            // The helper lost the session, or a reply no longer opens with our key: it is out of step.
            dropSession()
            state = .unpaired
        case .queryFailed, .loginNotFound, .cancelled, .insecureOrigin, .randomnessUnavailable,
            .notPermitted:
            break
        }
    }

    // MARK: - Actions - Events

    private func listen(to queue: ApplePasswordsRequestQueue, generation current: Int) {
        events = Task { [weak self] in
            for await event in queue.events {
                guard let self, self.generation == current else { return }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: ApplePasswordsRequestQueue.Event) {
        switch event {
        case .push:
            dropSession()
            state = .unpaired
        case .invalidated:
            tearDown()
            state = .unpaired
        case .closed(let reason):
            fail(because: reason)
        }
    }
}
