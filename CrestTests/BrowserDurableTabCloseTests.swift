import XCTest

@testable import Crest

@MainActor
final class BrowserDurableTabCloseTests: XCTestCase {
    func testCloseResumesByDefaultAndResetPersistsWithoutChangingDurableIdentity() throws {
        for placement: TabPlacement in [.pinned, .saved] {
            for policy in BrowserDurableTabClosePolicy.allCases {
                let context = try makeContext(placement: placement)
                // The core puts the page away as the session's preferences say.
                let preferences = BrowserAppPreferenceStore()
                preferences.bind(to: context.browser, legacy: BrowserLegacyAppPreferences())
                preferences.savedTabClosePolicy = policy
                var discardedState: Bool?
                let action = BrowserDurableTabCloseAction(
                    browser: context.browser,
                    spaceAccess: BrowserSpaceAccessController(),
                    preferences: preferences,
                    closePage: { assignment, discardState in
                        XCTAssertEqual(assignment, context.assignment)
                        discardedState = discardState
                        return true
                    }
                )

                XCTAssertTrue(action.perform(context.assignment))

                let space = try XCTUnwrap(context.browser.spaceModel(context.assignment.spaceID)).value.seed
                var expected = context.tab
                if policy == .returnToSavedURL { expected.url = expected.savedURL ?? expected.url }
                XCTAssertEqual(space.tabs.first, expected)
                XCTAssertEqual(discardedState, policy == .returnToSavedURL)
                XCTAssertNil(context.browser.selectedTab)
                XCTAssertEqual(space.tabs.last, context.copy)
                XCTAssertEqual(space.archivedTabs, context.archived)
            }
        }
    }

    func testStaleLockedAndOrdinaryTabsDoNotCloseOrDiscardState() throws {
        for placement: TabPlacement in [.current, .pinned, .saved] {
            let context = try makeContext(placement: placement)
            var closeCount = 0
            let action = BrowserDurableTabCloseAction(
                browser: context.browser,
                spaceAccess: BrowserSpaceAccessController(),
                preferences: BrowserAppPreferenceStore(),
                closePage: { _, _ in
                    closeCount += 1
                    return true
                }
            )
            let original = context.browser.session
            let stale = BrowserTabRuntimeAssignment(
                tabID: context.tab.id, spaceID: context.assignment.spaceID, profileID: UUID()
            )
            XCTAssertFalse(action.perform(stale))
            if placement == .current { XCTAssertFalse(action.perform(context.assignment)) }
            XCTAssertEqual(context.browser.session, original)

            context.browser.updateSpaceAccessPolicy(.deviceOwnerAuthentication, in: context.assignment.spaceID)
            XCTAssertFalse(action.perform(context.assignment))
            XCTAssertEqual(closeCount, 0)
        }
    }

    func testMismatchedResidentPageLeavesTheSessionUntouched() throws {
        let context = try makeContext(placement: .saved)
        let preferences = BrowserAppPreferenceStore()
        preferences.savedTabClosePolicy = .returnToSavedURL
        let original = context.browser.session
        let action = BrowserDurableTabCloseAction(
            browser: context.browser, spaceAccess: BrowserSpaceAccessController(),
            preferences: preferences, closePage: { _, _ in false }
        )
        XCTAssertFalse(action.perform(context.assignment))
        XCTAssertEqual(context.browser.session, original)
    }

    func testDeferredCloseOnlyArchivesAfterApproval() throws {
        let context = try makeContext(placement: .current)
        let gate = DeferredDismissal()
        context.browser.family.pageDismissalAuthorizer = gate
        let original = context.browser.session
        XCTAssertFalse(context.browser.closeTab(context.tab.id))
        XCTAssertEqual(context.browser.session, original)
        XCTAssertFalse(gate.resolve(false))
        XCTAssertEqual(context.browser.session, original)
        XCTAssertFalse(context.browser.closeTab(context.tab.id))
        XCTAssertTrue(gate.resolve(true))
        XCTAssertFalse(context.browser.selectedSpace!.tabs.contains { $0.id == context.tab.id })
        XCTAssertTrue(context.browser.selectedSpace!.archivedTabs.contains { $0.id == context.tab.id })
    }

    func testDeferredClearDoesNotCloseTabsOpenedWhileConfirmationWasPending() throws {
        let context = try makeContext(placement: .current)
        let gate = DeferredDismissal()
        context.browser.family.pageDismissalAuthorizer = gate
        let space = try XCTUnwrap(context.browser.selectedSpace)
        XCTAssertFalse(context.browser.clearCurrentTabs(matching: BrowserSpaceRuntimeAssignment(space: space)))
        let newTab = try XCTUnwrap(context.browser.openNewTab(url: URL(string: "https://example.net/new")!))
        let beforeReply = context.browser.session
        XCTAssertFalse(gate.resolve(true))
        XCTAssertEqual(context.browser.session, beforeReply)
        XCTAssertTrue(context.browser.selectedSpace!.tabs.contains { $0.id == newTab })
    }

    func testDeferredCloseRechecksTheTabAssignment() throws {
        let context = try makeContext(placement: .current)
        let gate = DeferredDismissal()
        context.browser.family.pageDismissalAuthorizer = gate
        XCTAssertFalse(context.browser.closeTab(context.tab.id))
        context.browser.family.pageDismissalAuthorizer = nil
        context.browser.deleteTab(context.tab.id, in: context.assignment.spaceID)
        let beforeReply = context.browser.session
        XCTAssertFalse(gate.resolve(true))
        XCTAssertEqual(context.browser.session, beforeReply)
    }

    func testDurablePageIsNotRetiredWhenCloseIsCanceled() throws {
        let context = try makeContext(placement: .saved)
        let gate = DeferredDismissal()
        context.browser.family.pageDismissalAuthorizer = gate
        var retired = 0
        let action = BrowserDurableTabCloseAction(browser: context.browser,
            spaceAccess: BrowserSpaceAccessController(), preferences: BrowserAppPreferenceStore(),
            closePage: { _, _ in retired += 1; return true })
        let original = context.browser.session
        XCTAssertFalse(action.perform(context.assignment))
        XCTAssertEqual(retired, 0)
        XCTAssertFalse(gate.resolve(false))
        XCTAssertEqual(retired, 0)
        XCTAssertEqual(context.browser.session, original)
        XCTAssertFalse(action.perform(context.assignment))
        XCTAssertTrue(gate.resolve(true))
        XCTAssertEqual(retired, 1)
    }

    private final class DeferredDismissal: BrowserPageDismissalAuthorizing {
        var pending: (@MainActor () -> Bool)?
        func performDismissal(of assignments: [BrowserTabRuntimeAssignment], in browser: BrowserStore,
            operation: @escaping @MainActor () -> Bool) -> Bool {
            pending = operation
            return false
        }
        func resolve(_ allowed: Bool) -> Bool {
            let operation = pending
            pending = nil
            return allowed && operation?() == true
        }
    }

    private func makeContext(placement: TabPlacement) throws -> Context {
        let root = try XCTUnwrap(URL(string: "https://example.com/root"))
        let child = try XCTUnwrap(URL(string: "https://example.com/child"))
        let tab = TabState.Seed(title: "Durable", url: child, savedURL: root, placement: placement)
        let copy = TabState.Seed(title: "Independent copy", url: child, placement: .current)
        let archived = [
            ArchivedTabState.Seed(
                tab: TabState.Seed(title: "Archive", url: child, placement: .current), archivedAt: .now,
                reason: .closed)
        ]
        let space = SpaceState.Seed(
            name: "Test", symbol: "circle", accent: .indigo,
            folders: [], tabs: [tab, copy], archivedTabs: archived
        )
        let browser = BrowserStore(
            seed: SessionState.Seed(spaces: [space]),
            showing: space.id, tabs: [space.id: tab.id]
        )
        return Context(
            browser: browser, tab: tab, copy: copy, archived: archived,
            assignment: BrowserTabRuntimeAssignment(tabID: tab.id, spaceID: space.id, profileID: space.profileID)
        )
    }

    private struct Context {
        let browser: BrowserStore
        let tab: TabState.Seed
        let copy: TabState.Seed
        let archived: [ArchivedTabState.Seed]
        let assignment: BrowserTabRuntimeAssignment
    }
}
