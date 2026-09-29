import Foundation
import XCTest

@testable import Crest

@MainActor
final class EnginePageAvailabilityTests: XCTestCase {
    func testDeferredAndClosedPagesHaveNoQueryableDocument() {
        let pages = StartingEnginePages()
        let page = EnginePage(
            id: UUID(), pages: pages, historyFamily: .chromium, historyVersion: { nil }, inspectorPanels: [])

        XCTAssertTrue(page.mediaActivity.isEmpty)
        XCTAssertNil(page.serverTrust(host: "example.com"))
        XCTAssertFalse(page.isInspected)
        XCTAssertEqual(pages.queries, 0)

        pages.isReady = true
        XCTAssertEqual(page.mediaActivity, [.playing])
        XCTAssertEqual(pages.queries, 1)

        page.close()
        XCTAssertTrue(page.mediaActivity.isEmpty)
        XCTAssertNil(page.serverTrust(host: "example.com"))
        XCTAssertFalse(page.isInspected)
        XCTAssertEqual(pages.queries, 1)
    }
}

@MainActor
private final class StartingEnginePages: EnginePages {
    var isReady = false
    private(set) var queries = 0

    func attach(_ page: EnginePage) {}

    func request<Request: PageRequest>(_ request: Request) -> Request.Answer {
        queries += 1
        precondition(request is PageMedia)
        var writer = WireWriter()
        PageMediaState(activity: [.playing]).encode(into: &writer)
        var reader = WireReader(writer.bytes)
        do { return try Request.decodeAnswer(from: &reader) } catch {
            preconditionFailure("The media answer must use its generated codec.")
        }
    }
}
