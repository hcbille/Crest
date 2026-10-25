import XCTest

@testable import Crest

/// The helper's gates and the request queue's matching rules, against a fake
/// channel. No process is started.
@MainActor
final class ApplePasswordsHelperTests: XCTestCase {
    func testTheLauncherRefusesAnIsolatedLaunch() {
        let isolated = BrowserLaunchEnvironment(values: ["CREST_ISOLATED_SESSION": "1"], isXCTestRuntime: false)
        let launcher = ApplePasswordsProcessLauncher(launchEnvironment: isolated)

        XCTAssertThrowsError(try launcher.launch()) {
            XCTAssertEqual($0 as? ApplePasswordsUnavailability, .isolatedLaunch)
        }
    }

    func testTheHelperDoesNothingUnlessTheCoreStartsIt() async throws {
        let helper = ApplePasswordsHelper(launcher: RefusingLauncher())
        let origin = CredentialOrigin(scheme: "https", host: "example.com", port: 443)
        let refused = ApplePasswordsTestSupport.refused

        await helper.start(support: refused)
        XCTAssertEqual(helper.state, .stopped)

        await assertNotPermitted { try await helper.requestPairingCode(support: refused) }
        await assertNotPermitted { try await helper.completePairing(code: "123456", support: refused) }
        await assertNotPermitted { _ = try await helper.logins(for: origin, support: refused) }
        await assertNotPermitted { _ = try await helper.password(for: origin, username: "ada", support: refused) }
        XCTAssertEqual(helper.state, .stopped)

        // Pairing may go on while the answer is "pairing required", but reading logins needs "available".
        let pairing = ApplePasswordsTestSupport.pairing
        XCTAssertFalse(pairing.status.offersApplePasswords)
        await assertNotPermitted { _ = try await helper.logins(for: origin, support: pairing) }
        await assertNotPermitted { _ = try await helper.password(for: origin, username: "ada", support: pairing) }
    }

    func testAMalformedCodeDoesNotSpendTheChallenge() async throws {
        let channel = FakeApplePasswordsChannel()
        channel.script = ApplePasswordsPairingScript.respond(on: channel)
        let helper = ApplePasswordsHelper(launcher: FakeApplePasswordsLauncher(channel: channel))
        let support = ApplePasswordsTestSupport.pairing

        try await helper.requestPairingCode(support: support)
        XCTAssertEqual(helper.state, .awaitingCode)
        let sentBefore = channel.sentCount

        for malformed in ["12345", "1234567", "12345a", "١٢٣٤٥٦", ""] {
            do {
                try await helper.completePairing(code: malformed, support: support)
                XCTFail("A code that is not six digits must be refused.")
            } catch {
                XCTAssertEqual(error as? ApplePasswordsPairingError, .malformedCode)
            }
        }
        XCTAssertEqual(channel.sentCount, sentBefore, "Nothing reaches the helper for a malformed code.")
        XCTAssertEqual(helper.state, .awaitingCode)

        // The same challenge still answers a well-formed code.
        do {
            try await helper.completePairing(code: "123456", support: support)
            XCTFail("The fake helper refuses every code.")
        } catch {
            XCTAssertEqual(error as? ApplePasswordsPairingError, .wrongCode)
        }
        XCTAssertEqual(channel.sentCount, sentBefore + 1)
        XCTAssertEqual(helper.state, .unpaired)
        helper.stop()
    }

    func testCancellingPairingTellsTheHelperThenSpendsTheChallengeWithAnEmptyCode() async throws {
        let channel = FakeApplePasswordsChannel()
        channel.script = ApplePasswordsPairingScript.respond(on: channel)
        let helper = ApplePasswordsHelper(launcher: FakeApplePasswordsLauncher(channel: channel))
        let support = ApplePasswordsTestSupport.pairing

        helper.cancelPairing()
        XCTAssertEqual(channel.sentCount, 0, "With no code waiting there is nothing to cancel.")

        try await helper.requestPairingCode(support: support)
        let sentBefore = channel.sentCount
        helper.cancelPairing()

        let sent = channel.sentPayloads.dropFirst(sentBefore)
        XCTAssertEqual(sent.count, 2)
        let cancel = try XCTUnwrap(JSONSerialization.jsonObject(with: sent[sentBefore]) as? [String: Any])
        XCTAssertEqual(cancel["cmd"] as? Int, 19)
        let proof = try XCTUnwrap(JSONSerialization.jsonObject(with: sent[sentBefore + 1]) as? [String: Any])
        XCTAssertEqual(proof["cmd"] as? Int, 2)
        XCTAssertEqual(helper.state, .unpaired)

        // The refusal of the empty code may arrive after pairing starts again; it must not answer the new hello.
        try await helper.requestPairingCode(support: support)
        XCTAssertEqual(helper.state, .awaitingCode)
        helper.stop()
    }

    func testPairingStartedAgainDiscardsTheEarlierProof() async throws {
        let channel = FakeApplePasswordsChannel()
        channel.script = ApplePasswordsPairingScript.respond(on: channel, answersProofs: false)
        let helper = ApplePasswordsHelper(launcher: FakeApplePasswordsLauncher(channel: channel))
        let support = ApplePasswordsTestSupport.pairing
        try await helper.requestPairingCode(support: support)

        let proof = Task { try await helper.completePairing(code: "123456", support: support) }
        await waitUntil { channel.sentCount == 3 }
        let restarted = Task { try await helper.requestPairingCode(support: support) }
        await waitUntil { helper.state == .unpaired }

        // The helper accepts the first proof, but pairing has started over.
        let identity = try XCTUnwrap(channel.lastIdentity)
        let accepted = try JSONSerialization.data(withJSONObject: ["TID": identity, "MSG": 3, "HAMK": "00"])
        channel.deliver(#"{"cmd":2,"payload":{"PAKE":"\#(accepted.base64EncodedString())"}}"#)
        do {
            try await proof.value
            XCTFail("An earlier proof must not pair.")
        } catch {
            XCTAssertEqual(error as? ApplePasswordsError, .cancelled)
        }
        try await restarted.value
        XCTAssertEqual(helper.state, .awaitingCode)
        helper.stop()
    }

    func testACancelledCallerDetachesAndItsLateReplyIsDiscarded() async throws {
        let channel = FakeApplePasswordsChannel()
        let queue = ApplePasswordsRequestQueue(channel: channel)
        let first = Task { try await queue.submit(ApplePasswordsCapabilitiesRequest()) }
        await waitUntil { channel.sentCount == 1 }
        let second = Task { try await queue.submit(ApplePasswordsCapabilitiesRequest()) }

        first.cancel()
        do {
            _ = try await first.value
            XCTFail("A cancelled caller gets no reply.")
        } catch {
            XCTAssertEqual(error as? ApplePasswordsError, .cancelled)
        }
        // The cancelled request is still in flight, so the next one waits for it.
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(channel.sentCount, 1)

        channel.deliver(#"{"cmd":14,"capabilities":{"shouldUseBase64":true}}"#)
        await waitUntil { channel.sentCount == 2 }

        channel.deliver(#"{"cmd":14,"capabilities":{"shouldUseBase64":false}}"#)
        let capabilities = try await second.value
        XCTAssertEqual(capabilities.shouldUseBase64, false, "The late reply went to nobody.")
        channel.terminate()
        await queue.shutdown()
    }

    // MARK: - Fixtures

    private func assertNotPermitted(
        _ work: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await work()
            XCTFail("The core did not allow the helper.", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ApplePasswordsError, .notPermitted, file: file, line: line)
        }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// Answers the core would give, built here because app code never builds one.
enum ApplePasswordsTestSupport {
    static let available = ApplePasswordsSupport(status: .available, offersToTurnOffExtension: false)
    static let pairing = ApplePasswordsSupport(status: .pairingRequired, offersToTurnOffExtension: false)
    static let refused = ApplePasswordsSupport(status: .turnedOff, offersToTurnOffExtension: false)
}

/// A launcher that fails the test if anything asks it to start a helper.
struct RefusingLauncher: ApplePasswordsChannelLauncher {
    func launch() throws -> any ApplePasswordsChannel {
        XCTFail("No helper may be launched.")
        throw ApplePasswordsUnavailability.launchFailed
    }
}

struct FakeApplePasswordsLauncher: ApplePasswordsChannelLauncher {
    let channel: FakeApplePasswordsChannel

    func launch() throws -> any ApplePasswordsChannel { channel }
}

final class FakeApplePasswordsChannel: ApplePasswordsChannel, @unchecked Sendable {
    let events: AsyncStream<ApplePasswordsChannelEvent>
    /// Called with each payload Crest sends, to answer it.
    var script: (@Sendable (Data) -> Void)?
    private let continuation: AsyncStream<ApplePasswordsChannelEvent>.Continuation
    private let lock = NSLock()
    private var sent: [Data] = []
    private var identity: String?

    init() {
        (events, continuation) = AsyncStream.makeStream(of: ApplePasswordsChannelEvent.self)
    }

    /// The session identifier of the latest handshake message Crest sent.
    var lastIdentity: String? {
        lock.withLock { identity }
    }

    func record(identity: String) {
        lock.withLock { self.identity = identity }
    }

    var sentCount: Int {
        lock.withLock { sent.count }
    }

    var sentPayloads: [Data] {
        lock.withLock { sent }
    }

    func send(_ payload: Data) throws {
        lock.withLock { sent.append(payload) }
        script?(payload)
    }

    func terminate() {
        continuation.finish()
    }

    func deliver(_ json: String) {
        continuation.yield(.frame(Data(json.utf8)))
    }
}

/// A helper that reports capabilities, issues a challenge and refuses every code.
enum ApplePasswordsPairingScript {
    static func respond(
        on channel: FakeApplePasswordsChannel,
        answersProofs: Bool = true
    ) -> @Sendable (Data) -> Void {
        { [unowned channel] payload in
            guard let message = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                let command = message["cmd"] as? Int
            else { return }
            switch command {
            case 14:
                channel.deliver(#"{"cmd":14,"capabilities":{"secretSessionVersion":1}}"#)
            case 2:
                let inner = (message["msg"] as? String).flatMap {
                    try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]
                }
                let step = (inner?["PAKE"] as? String).flatMap { Data(base64Encoded: $0) }
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let identity = step?["TID"] as? String ?? ""
                channel.record(identity: identity)
                if inner?["QID"] as? String != "m0" && !answersProofs { return }
                let answer: [String: Any] =
                    inner?["QID"] as? String == "m0"
                    ? ["TID": identity, "MSG": 1, "PROTO": 1, "B": "0x02", "s": "0x0102"]
                    : ["TID": identity, "MSG": 3, "ErrCode": 1]
                let pake = (try? JSONSerialization.data(withJSONObject: answer))?.base64EncodedString() ?? ""
                channel.deliver(#"{"cmd":2,"payload":{"PAKE":"\#(pake)"}}"#)
            default:
                break
            }
        }
    }
}
