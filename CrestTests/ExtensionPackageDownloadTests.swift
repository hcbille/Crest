import Foundation
import XCTest

@testable import Crest

/// What keeps an extension install safe when the engine's own download is silent and the package is fetched
/// from the Web Store directly: the address that is sent, which downloaded files are accepted as packages,
/// and that exactly one download is ever used and the other leaves no file behind.
final class ExtensionPackageDownloadTests: XCTestCase {
    private let identifier = "cjpalhdlnbpafiamejdnhcphjbkeiagm"
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "extension-package-tests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - The address

    func testTheAddressCarriesTheIdentifierAndTheEngineVersion() throws {
        let url = try XCTUnwrap(ExtensionFallbackDownload.url(id: identifier, engineVersion: "154.0.8037.57"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "clients2.google.com")
        XCTAssertEqual(components.path, "/service/update2/crx")
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["prodversion"], "154.0.8037.57")
        XCTAssertEqual(items["response"], "redirect")
        XCTAssertEqual(items["x"], "id=\(identifier)&installsource=ondemand&uc")
    }

    func testAnIdentifierThatIsNotAWebStoreIdentifierGetsNoAddress() {
        let notIdentifiers = [
            "", "short", String(identifier.dropLast()), identifier + "a", identifier.uppercased(),
            String(identifier.dropLast()) + "q", String(identifier.dropLast()) + "é", "../" + identifier,
        ]
        for candidate in notIdentifiers {
            XCTAssertNil(ExtensionFallbackDownload.url(id: candidate, engineVersion: "154.0.8037.57"), candidate)
        }
    }

    func testAVersionCannotAddOrChangeAQueryValue() throws {
        let url = try XCTUnwrap(ExtensionFallbackDownload.url(id: identifier, engineVersion: "1.2 3&x=1#frag"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []

        XCTAssertEqual(items.filter { $0.name == "x" }.count, 1)
        XCTAssertEqual(items.first { $0.name == "prodversion" }?.value, "1.2 3&x=1#frag")
        XCTAssertNil(components.fragment)
        XCTAssertNil(ExtensionFallbackDownload.url(id: identifier, engineVersion: ""))
    }

    // MARK: - Which files are accepted

    func testAChromePackageIsAcceptedAndMovedToAFileTheCallerOwns() throws {
        let downloaded = try file(crx3Header + [1, 2, 3])
        let result = ExtensionFallbackDownload.ownedPackage(location: downloaded, response: response(200), error: nil)

        let kept = try XCTUnwrap(try? result.get())
        defer { try? FileManager.default.removeItem(at: kept) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: downloaded.path))
        XCTAssertEqual(try Data(contentsOf: kept), Data(crx3Header + [1, 2, 3]))
    }

    func testAnythingThatIsNotAChromePackageIsRefused() throws {
        let refused: [(String, [UInt8])] = [
            ("empty", []),
            ("shorter than a header", [0x43, 0x72, 0x32, 0x34]),
            ("a zip file", [0x50, 0x4B, 0x03, 0x04, 3, 0, 0, 0]),
            ("an older package format", [0x43, 0x72, 0x32, 0x34, 2, 0, 0, 0]),
            ("a newer package format", [0x43, 0x72, 0x32, 0x34, 4, 0, 0, 0]),
            ("a format version in the wrong byte order", [0x43, 0x72, 0x32, 0x34, 0, 0, 0, 3]),
        ]
        for (name, bytes) in refused {
            let downloaded = try file(bytes)
            let result = ExtensionFallbackDownload.ownedPackage(
                location: downloaded, response: response(200), error: nil)
            XCTAssertNil(try? result.get(), name)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: downloaded.path), "\(name): the file is left to the system")
        }
    }

    func testAResponseThatIsNotAnHTTPSSuccessIsRefusedWhateverTheFileHolds() throws {
        let responses: [(String, URLResponse?)] = [
            ("not found", response(404)),
            ("no content", response(204)),
            ("server error", response(500)),
            ("plain http", response(200, address: "http://clients2.googleusercontent.com/crx/blob.crx")),
            (
                "not an HTTP response",
                URLResponse(
                    url: URL(fileURLWithPath: "/"), mimeType: nil, expectedContentLength: 8, textEncodingName: nil)
            ),
            ("no response", nil),
        ]
        for (name, candidate) in responses {
            let downloaded = try file(crx3Header)
            let result = ExtensionFallbackDownload.ownedPackage(location: downloaded, response: candidate, error: nil)
            XCTAssertNil(try? result.get(), name)
        }
        let missing = ExtensionFallbackDownload.ownedPackage(location: nil, response: response(200), error: nil)
        XCTAssertNil(try? missing.get())
    }

    func testAFailedOrStoppedDownloadSaysWhyAndKeepsNothing() throws {
        let canceled = ExtensionFallbackDownload.ownedPackage(
            location: nil, response: nil, error: URLError(.cancelled))
        let tooLarge = ExtensionFallbackDownload.ownedPackage(
            location: nil, response: nil, error: URLError(.cancelled), oversized: true)
        let offline = ExtensionFallbackDownload.ownedPackage(
            location: nil, response: nil, error: URLError(.notConnectedToInternet))

        guard case .failure(let canceledFailure) = canceled, case .failure(let largeFailure) = tooLarge,
            case .failure(let offlineFailure) = offline
        else { return XCTFail("every one of these must fail") }
        XCTAssertEqual(canceledFailure.reason, "canceled")
        XCTAssertTrue(largeFailure.reason.contains("larger"), largeFailure.reason)
        XCTAssertFalse(offlineFailure.reason.isEmpty)
    }

    // MARK: - Exactly one download is used

    func testTheEnginesPackageWinsAndALaterOneIsDeleted() async throws {
        let race = ExtensionPackageRace()
        let engine = try file(crx3Header + [1])
        let late = try file(crx3Header + [2])
        let waiting = Task { try await race.wait() }

        race.engineFinished(package: engine.path, message: "")
        let win = try await waiting.value
        let accepted = race.offer(late, from: .urlSession)

        XCTAssertEqual(win.source, .engine)
        XCTAssertEqual(win.package, engine)
        XCTAssertFalse(accepted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: engine.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: late.path))
    }

    func testASilentEngineLetsTheSecondDownloadWinAndTheEnginesLatePackageIsDeleted() async throws {
        let race = ExtensionPackageRace()
        let fetched = try file(crx3Header + [1])
        let late = try file(crx3Header + [2])

        XCTAssertTrue(race.beginFallback())
        XCTAssertFalse(race.beginFallback(), "the second download is claimed once")
        XCTAssertTrue(race.offer(fetched, from: .urlSession))
        race.engineFinished(package: late.path, message: "")

        // Waiting after the race has ended returns the same outcome at once.
        let win = try await race.wait()
        XCTAssertEqual(win.source, .urlSession)
        XCTAssertEqual(win.package, fetched)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fetched.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: late.path))
    }

    func testAnEngineThatHasSpokenIsNeverJoinedByASecondDownload() {
        let progressed = ExtensionPackageRace()
        progressed.engineReportedProgress()
        XCTAssertFalse(progressed.beginFallback())

        let finished = ExtensionPackageRace()
        finished.engineFinished(package: nil, message: "no", unavailable: false)
        XCTAssertFalse(finished.beginFallback())

        let ended = ExtensionPackageRace()
        ended.abort(CancellationError())
        XCTAssertFalse(ended.beginFallback())
    }

    func testTheRaceStaysOpenWhileOneDownloadCanStillDeliver() async throws {
        let race = ExtensionPackageRace()
        XCTAssertTrue(race.beginFallback())
        race.engineFinished(package: nil, message: "engine gave up")

        // The second download is still running, so it can still win.
        let fetched = try file(crx3Header)
        XCTAssertTrue(race.offer(fetched, from: .urlSession))
        let win = try await race.wait()
        XCTAssertEqual(win.package, fetched)
    }

    func testBothDownloadsFailingEndsTheRaceWithTheEnginesMessageFirst() async throws {
        let race = ExtensionPackageRace()
        XCTAssertTrue(race.beginFallback())
        XCTAssertTrue(race.fallbackFailed("HTTP status 404"), "the race is still open when only one download failed")
        race.engineFinished(package: nil, message: "engine says no")

        do {
            _ = try await race.wait()
            XCTFail("both downloads failed")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "CrestExtension")
            XCTAssertTrue(error.localizedDescription.contains("engine says no"), error.localizedDescription)
        }
    }

    func testTheSecondDownloadsReasonIsUsedWhenTheEngineGivesNone() async {
        let race = ExtensionPackageRace()
        XCTAssertTrue(race.beginFallback())
        race.engineFinished(package: nil, message: "")
        XCTAssertTrue(race.fallbackFailed("HTTP status 404"), "the race was open until this failure")

        do {
            _ = try await race.wait()
            XCTFail("both downloads failed")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("HTTP status 404"), error.localizedDescription)
        }
    }

    func testAnEngineFailureEndsTheRaceAtOnceWhenNoSecondDownloadWasStarted() async {
        let race = ExtensionPackageRace()
        race.engineFinished(package: nil, message: "engine says no")

        do {
            _ = try await race.wait()
            XCTFail("the engine failed and nothing else is running")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("engine says no"), error.localizedDescription)
        }
    }

    func testAnEngineThatCannotStartEndsTheRaceWithAnError() async {
        let race = ExtensionPackageRace()
        race.engineFinished(package: nil, message: "", unavailable: true)

        do {
            _ = try await race.wait()
            XCTFail("there is nothing to download with")
        } catch {
            XCTAssertEqual((error as NSError).domain, "CrestExtension")
        }
    }

    func testCancellingTheWaiterEndsTheRaceAndDeletesAPackageThatArrivesAfterwards() async throws {
        let race = ExtensionPackageRace()
        let waiting = Task { try await race.wait() }
        try await Task.sleep(for: .milliseconds(50))
        waiting.cancel()

        do {
            _ = try await waiting.value
            XCTFail("the wait was cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
        let late = try file(crx3Header)
        XCTAssertFalse(race.offer(late, from: .urlSession))
        XCTAssertFalse(FileManager.default.fileExists(atPath: late.path))
    }

    func testPackagesOfferedAtOnceProduceOneWinnerAndLeaveNoOtherFile() async throws {
        let race = ExtensionPackageRace()
        let files = try (0..<24).map { try file(crx3Header + [UInt8($0)]) }

        let accepted = await withTaskGroup(of: Bool.self) { group in
            for (index, package) in files.enumerated() {
                group.addTask { race.offer(package, from: index.isMultiple(of: 2) ? .engine : .urlSession) }
            }
            return await group.reduce(into: 0) { count, won in count += won ? 1 : 0 }
        }
        let remaining = files.filter { FileManager.default.fileExists(atPath: $0.path) }
        let win = try await race.wait()

        XCTAssertEqual(accepted, 1)
        XCTAssertEqual(remaining, [win.package])
    }

    // MARK: - Fixtures

    private let crx3Header: [UInt8] = [0x43, 0x72, 0x32, 0x34, 3, 0, 0, 0]

    private func file(_ bytes: [UInt8]) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID()).crx")
        try Data(bytes).write(to: url)
        return url
    }

    private func response(_ status: Int, address: String = "https://clients2.googleusercontent.com/crx/blob.crx")
        -> HTTPURLResponse
    {
        HTTPURLResponse(url: URL(string: address)!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
    }
}
