import XCTest

@testable import Crest

@MainActor
final class BrowserSetupFinishTests: XCTestCase {
    func testFinishingOpensTheGuideInTheFirstSpaceOnceAndCompletesSetup() async throws {
        let browser = BrowserStore.preview()
        let first = try XCTUnwrap(browser.session.spaces.first)
        browser.selectSpace(try XCTUnwrap(browser.session.spaces.last?.id))
        let originalTabs = first.tabs
        let access = BrowserSpaceAccessController()

        try browser.core.send(StartSetup(workspaceID: browser.family.workspaceID, entry: .firstRun))
        let result = await BrowserSetupFinish.finish(browser: browser, spaceAccess: access)

        guard case .completed(let opened) = result, let guide = opened else { return XCTFail("No guide opened") }
        XCTAssertEqual(guide.spaceID, first.id)
        XCTAssertEqual(guide.profileID, first.profile.id)
        XCTAssertEqual(browser.selectedTab?.id, guide.tabID)
        XCTAssertEqual(browser.selectedSpace?.tabs.filter { $0.nativeContent != .gettingStarted }, originalTabs)
        XCTAssertEqual(browser.core.state.setupCompleted, true)

        try browser.core.send(StartSetup(workspaceID: browser.family.workspaceID, entry: .rerun))
        let replay = await BrowserSetupFinish.finish(browser: browser, spaceAccess: access)
        XCTAssertEqual(replay, .completed(guide: guide))
        XCTAssertEqual(browser.selectedSpace?.tabs.filter { $0.nativeContent == .gettingStarted }.count, 1)
    }

    /// The guide never opens in a locked first Space. Finishing asks to unlock
    /// it first; a refusal applies nothing and leaves setup to finish, and
    /// the retry applies the manual setup once over whatever changed meanwhile.
    func testARefusedUnlockLeavesSetupUnfinishedUntilARetryAppliesTheManualSetupOnce() async throws {
        var session = BrowserSession.preview
        session.spaces[0].accessPolicy = .deviceOwnerAuthentication
        let browser = BrowserStore(session: session)
        let authenticator = SetupFinishAuthenticator()
        let access = BrowserSpaceAccessController(authenticator: authenticator)
        browser.attachSpaceAccess(access)
        try browser.core.send(StartSetup(workspaceID: browser.family.workspaceID, entry: .firstRun))
        try browser.core.send(ShowSetupStep(step: .manualSetup))
        let setup = BrowserManualSetupModel(core: browser.core)
        let addedID = try XCTUnwrap(setup.addSpace())
        let before = browser.session

        let refused = Task { await BrowserSetupFinish.finish(browser: browser, spaceAccess: access) }
        await authenticator.waitForRequest()
        authenticator.resolve(false)
        let refusal = await refused.value
        XCTAssertEqual(refusal, .cancelled)
        XCTAssertEqual(browser.session, before)
        XCTAssertNotNil(setup.draft)
        XCTAssertNotEqual(browser.core.state.setupCompleted, true)

        let retry = Task { await BrowserSetupFinish.finish(browser: browser, spaceAccess: access) }
        await authenticator.waitForRequest()
        let updated = browser.session.spaces[1]
        XCTAssertTrue(browser.setTabCustomTitle("Updated during setup", for: updated.tabs[0].id, in: updated.id))
        authenticator.resolve(true)
        guard case .completed(let guide) = await retry.value else { return XCTFail("Setup did not complete") }
        XCTAssertEqual(guide?.spaceID, before.spaces.first?.id)
        XCTAssertEqual(browser.session.spaces.filter { $0.id == addedID }.count, 1)
        XCTAssertEqual(browser.session.space(id: updated.id)?.tabs[0].customTitle, "Updated during setup")
        XCTAssertNil(setup.draft)
        XCTAssertEqual(browser.core.state.setupCompleted, true)
    }
}

@MainActor
private final class SetupFinishAuthenticator: BrowserDeviceAuthenticating {
    private var request: CheckedContinuation<Bool, Error>?
    private var waiter: CheckedContinuation<Void, Never>?

    func authenticate(reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            request = continuation
            waiter?.resume()
            waiter = nil
        }
    }

    func waitForRequest() async {
        if request != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func resolve(_ allowed: Bool) {
        let pending = request
        request = nil
        pending?.resume(returning: allowed)
    }
}
