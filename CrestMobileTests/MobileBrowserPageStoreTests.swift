import WebKit
import XCTest

@testable import CrestMobile

@MainActor
final class MobileBrowserPageStoreTests: XCTestCase {

    func testTabLinkReadsResidentBackgroundAddressAndNeverLoadsKnownUnloadedTabs() async throws {
        let root = try XCTUnwrap(URL(string: "https://copy.crest.test/root"))
        let current = try XCTUnwrap(URL(string: "https://copy.crest.test/child?q=a%20b#section"))
        let target = BrowserTab(title: "Saved", url: root, placement: .saved)
        let selected = BrowserTab.startPage()
        let unloaded = BrowserTab(title: "Pinned", url: root, placement: .pinned)
        var space = makeSpace(index: 321, savesCredentials: false)
        space.tabs = [target, selected, unloaded]
        let pages = MobileBrowserPageStore(
            browser: .hostingPages(BrowserSession(spaces: [space])), usesEphemeralWebsiteDataStores: true)
        defer { pages.reconcile(validTabIDs: []) }
        pages.select(session: presented(BrowserSession(spaces: [space]), showing: target.id))
        let page = try XCTUnwrap(pages.activePage)
        page.webView.loadSimulatedRequest(
            URLRequest(url: current), responseHTML: "<html><title>Copy fixture</title></html>")
        try await waitUntil { page.live.documentURL == current && !page.webView.isLoading }
        pages.select(session: presented(BrowserSession(spaces: [space]), showing: selected.id))
        let before = pages.residentPageCount
        let activePage = pages.activePage
        let history = page.webView.backForwardList.backList.map(\.url)

        XCTAssertEqual(
            pages.liveLinkURL(
                for: BrowserTabRuntimeAssignment(tabID: target.id, spaceID: space.id, profileID: space.profile.id)),
            current)
        XCTAssertNil(
            pages.liveLinkURL(
                for: BrowserTabRuntimeAssignment(tabID: unloaded.id, spaceID: space.id, profileID: space.profile.id)))
        XCTAssertEqual(pages.residentPageCount, before)
        XCTAssertFalse(pages.containsResidentPage(for: unloaded.id))
        XCTAssertEqual(page.webView.backForwardList.backList.map(\.url), history)
        XCTAssertEqual(target.savedURL, root)
        XCTAssertTrue(pages.activePage === activePage)
    }

    func testSplitCopiesDurablePagesWithIndependentNativeHistory() async throws {
        let root = try XCTUnwrap(URL(string: "https://state.crest.test/root"))
        let child = try XCTUnwrap(URL(string: "https://state.crest.test/child"))
        var session = makeSession(index: 304)
        let source = BrowserTab(title: "Saved", url: root, placement: .saved)
        let target = BrowserTab(title: "Pinned", url: root, placement: .pinned)
        session.spaces[0].tabs = [target, source]
        let space = try XCTUnwrap(session.spaces.first)
        let browser = BrowserStore.hostingPages(
            session,
            showing: space.id, tabs: [space.id: source.id])
        let pages = MobileBrowserPageStore(browser: browser, usesEphemeralWebsiteDataStores: true)
        browser.tabCopying = pages
        pages.select(session: browser.presented)
        let originalPage = try XCTUnwrap(pages.activePage)
        for url in [root, child] {
            originalPage.webView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
            originalPage.webView.loadSimulatedRequest(
                URLRequest(url: url),
                responseHTML: "<html><title>State fixture</title><body>Native history</body></html>"
            )
            try await waitUntil { originalPage.webView.url == url && !originalPage.webView.isLoading }
        }
        browser.selectTab(target.id)
        let originalPinnedTabs = browser.selectedSpace?.pinnedTabs

        XCTAssertTrue(browser.splitTabWithSelectedTab(source.id, matching: BrowserSpaceRuntimeAssignment(space: space)))
        let copy = try XCTUnwrap(browser.selectedTab)
        XCTAssertEqual(copy.url, child)
        XCTAssertNotEqual(copy.id, source.id)
        // The saved tab stays saved, where its page's recorded navigation left it.
        XCTAssertEqual(browser.selectedSpace?.savedTabs.map(\.id), [source.id])
        XCTAssertEqual(browser.selectedSpace?.pinnedTabs, originalPinnedTabs)
        // Copying an unmaterialized copy must leave its own native state available.
        var nextCopy = BrowserTab(title: copy.title, url: copy.url, placement: .current)
        pages.prepareTabCopy(from: copy, to: &nextCopy, in: space)
        pages.select(session: browser.presented)
        let copiedPage = try XCTUnwrap(pages.activePage)
        XCTAssertFalse(copiedPage === originalPage)
        XCTAssertEqual(copiedPage.webView.url, child)
        XCTAssertTrue(copiedPage.webView.canGoBack)
        XCTAssertEqual(
            copiedPage.webView.backForwardList.backList.map(\.url),
            originalPage.webView.backForwardList.backList.map(\.url))
        XCTAssertEqual(originalPage.webView.url, child)
        var nextSpace = try XCTUnwrap(browser.selectedSpace)
        nextSpace.tabs.append(nextCopy)
        pages.select(session: presented(BrowserSession(spaces: [nextSpace]), showing: nextCopy.id))
        XCTAssertTrue(try XCTUnwrap(pages.activePage).webView.canGoBack)
        pages.reconcile(validTabIDs: [])
    }

    func testStartPageCommandPaletteIssuesOneNavigationForAFreshPage() throws {
        let store = BrowserStore.hostingPages(
            makeSession(index: 0)
        )
        let pages = MobileBrowserPageStore(browser: store, usesEphemeralWebsiteDataStores: true)
        let url = try XCTUnwrap(URL(string: "https://example.com/search"))

        store.navigateSelectedTab(to: url.absoluteString)
        pages.selectAndNavigate(to: url.absoluteString, in: store.presented)

        XCTAssertEqual(
            try XCTUnwrap(pages.activePage).appInitiatedNavigationCount,
            1,
            "A Start Page submission must not ask a newly resident WebView to load twice."
        )
    }

    func testForegroundModifiedLinkCreatesSelectsAndLoadsOneCurrentSpacePage() throws {
        let store = BrowserStore.hostingPages(
            makeSession(index: 90)
        )
        let pages = makeLinkRoutingPageStore(browser: store)
        let sourceSpaceID = try XCTUnwrap(store.selectedSpace?.id)
        pages.select(session: store.presented)
        let sourcePage = try XCTUnwrap(pages.activePage)
        let url = try XCTUnwrap(URL(string: "https://slow.crest.test/foreground"))

        sourcePage.routeModifiedLink(url, selecting: true)

        XCTAssertEqual(store.selectedSpace?.id, sourceSpaceID)
        XCTAssertEqual(store.selectedTab?.url, url)
        XCTAssertEqual(pages.activePage?.tabID, store.selectedTab?.id)
        XCTAssertEqual(pages.activePage?.appInitiatedNavigationCount, 1)
    }

    func testBackgroundModifiedLinkLoadsBeforeSelectionAndIsReused() throws {
        let store = BrowserStore.hostingPages(
            makeSession(index: 91)
        )
        let pages = makeLinkRoutingPageStore(browser: store)
        pages.select(session: store.presented)
        let sourcePage = try XCTUnwrap(pages.activePage)
        let sourceTabID = try XCTUnwrap(store.selectedTab?.id)
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:9/offline"))

        sourcePage.routeModifiedLink(url, selecting: false)

        let openedTab = try XCTUnwrap(
            store.selectedSpace?.tabs.first { $0.id != sourceTabID }
        )
        XCTAssertEqual(store.selectedTab?.id, sourceTabID)
        XCTAssertTrue(pages.containsResidentPage(for: openedTab.id))

        store.selectTab(openedTab.id)
        pages.select(session: store.presented)

        XCTAssertEqual(pages.activePage?.tabID, openedTab.id)
        XCTAssertEqual(pages.activePage?.appInitiatedNavigationCount, 1)
    }

    // MARK: - Per-Space credential access

    func testDisablingCredentialAccessResetsAPendingFillRequest() throws {
        var session = makeSession(index: 3)
        let space = try XCTUnwrap(session.spaces.first)
        let pages = MobileBrowserPageStore(browser: .hostingPages(session), usesEphemeralWebsiteDataStores: true)
        pages.select(session: presented(session))
        let page = try XCTUnwrap(pages.activePage)
        let loginOrigin = try XCTUnwrap(
            CredentialOrigin(url: try XCTUnwrap(URL(string: "https://accounts.crest.test/login")))
        )
        page.credentialState.receive(
            try submitMessage(),
            frameOrigin: loginOrigin,
            topLevelOrigin: loginOrigin,
            isMainFrame: true,
            fillTarget: nil
        )
        page.credentialState.receive(
            try documentStateMessage(),
            frameOrigin: loginOrigin,
            topLevelOrigin: loginOrigin,
            isMainFrame: true,
            fillTarget: nil
        )
        XCTAssertNotNil(page.credentialSaveCandidate)

        var preferences = space.credentialPreferences
        preferences.isEnabled = false
        session.spaces[0].credentialPreferences = preferences
        pages.reconcileCredentialAccess(in: session)

        XCTAssertFalse(page.isCredentialAccessEnabled)
        XCTAssertNil(
            page.credentialSaveCandidate,
            "Turning saving off mid-session must take the pending save offer away with it."
        )
    }

    func testDisabledCredentialAccessRejectsAFillAndStopsFormCapture() async throws {
        let session = makeSession(index: 4, savesCredentials: false)
        let pages = MobileBrowserPageStore(browser: .hostingPages(session), usesEphemeralWebsiteDataStores: true)
        pages.select(session: presented(session))
        let page = try XCTUnwrap(pages.activePage)
        let request = URLRequest(
            url: try XCTUnwrap(URL(string: "https://forms.crest.test/login"))
        )
        page.webView.loadSimulatedRequest(
            request,
            responseHTML: """
                <!doctype html>
                <style>input { display: block; width: 220px; height: 32px; }</style>
                <form id="mobile-login">
                  <input autocomplete="username" value="mobile@example.com">
                  <input type="password" autocomplete="current-password" value="mobile-secret">
                  <button type="button">Sign In</button>
                </form>
                """
        )
        try await waitUntil { page.completedNavigationCount == 1 }

        let didCapture = try await page.webView.callAsyncJavaScript(
            "return globalThis.__crestCredentialBridge?.captureForTesting(selector) === true;",
            arguments: ["selector": "#mobile-login"],
            in: nil,
            contentWorld: BrowserCredentialContentBridge.contentWorld
        )
        XCTAssertEqual(didCapture as? Bool, true)
        _ = try await page.webView.callAsyncJavaScript(
            "document.querySelector('#mobile-login').remove(); return true;",
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        try await Task.sleep(for: .milliseconds(400))

        XCTAssertNil(
            page.credentialSaveCandidate,
            "A Space with saving off must never offer to save what a form submitted."
        )
        XCTAssertNil(page.credentialFillRequest)
        await assertThrowsErrorAsync(
            try await page.fillGeneratedPassword("generated", for: UUID())
        )
    }

    func testTransientPeekPagesFollowTheirSpacesCredentialPreference() throws {
        var session = makeSession(index: 5)
        let space = try XCTUnwrap(session.spaces.first)
        let pages = MobileBrowserPageStore(browser: .hostingPages(session), usesEphemeralWebsiteDataStores: true)
        let lease = try XCTUnwrap(
            pages.makeTransientPageLease(
                url: try XCTUnwrap(URL(string: "about:blank")),
                in: space
            )
        )
        XCTAssertTrue(try XCTUnwrap(lease.page).isCredentialAccessEnabled)

        var preferences = space.credentialPreferences
        preferences.isEnabled = false
        session.spaces[0].credentialPreferences = preferences
        pages.reconcileCredentialAccess(in: session)

        XCTAssertFalse(try XCTUnwrap(lease.page).isCredentialAccessEnabled)
    }

    func testDownloadOnlyTransientPageDismissesInsteadOfRemainingEmpty() async throws {
        let session = makeSession(index: 51)
        let space = try XCTUnwrap(session.spaces.first)
        let pages = MobileBrowserPageStore(browser: .hostingPages(session), usesEphemeralWebsiteDataStores: true)
        var dismissalCount = 0
        let lease = try XCTUnwrap(
            pages.makeTransientPageLease(
                url: try XCTUnwrap(URL(string: "about:blank")),
                in: space,
                onDownloadOnlyNavigation: { dismissalCount += 1 }
            )
        )
        let page = try XCTUnwrap(lease.page)

        page.discardDownloadOnlySurfaceIfNeeded()
        await Task.yield()

        XCTAssertEqual(dismissalCount, 1)
        XCTAssertNil(lease.page)
    }

    func testDownloadFromLoadedTransientPageKeepsItsExistingContent() async throws {
        let session = makeSession(index: 52)
        let space = try XCTUnwrap(session.spaces.first)
        let pages = MobileBrowserPageStore(browser: .hostingPages(session), usesEphemeralWebsiteDataStores: true)
        var dismissalCount = 0
        let lease = try XCTUnwrap(
            pages.makeTransientPageLease(
                url: try XCTUnwrap(URL(string: "about:blank")),
                in: space,
                onDownloadOnlyNavigation: { dismissalCount += 1 }
            )
        )
        let page = try XCTUnwrap(lease.page)
        page.webView(page.webView, didCommit: nil)

        page.discardDownloadOnlySurfaceIfNeeded()
        await Task.yield()

        XCTAssertEqual(dismissalCount, 0)
        XCTAssertNotNil(lease.page)
    }

    func testPrivateBrowsingKeepsCredentialAccessOffEvenWhenTheSpaceAllowsSaving() throws {
        let session = makeSession(index: 6)
        let pages = MobileBrowserPageStore(
            browser: .hostingPages(session, browsingMode: .privateBrowsing),
            browsingMode: .privateBrowsing,
            usesEphemeralWebsiteDataStores: true
        )

        pages.select(session: presented(session))

        XCTAssertFalse(try XCTUnwrap(pages.activePage).isCredentialAccessEnabled)
    }

    // MARK: - Memory pressure

    func testCriticalPressureEventReleasesTheActiveTransientLeaseAWarningKeeps() throws {
        let session = makeSession(index: 7)
        let space = try XCTUnwrap(session.spaces.first)
        let pages = MobileBrowserPageStore(browser: .hostingPages(session), usesEphemeralWebsiteDataStores: true)
        let url = try XCTUnwrap(URL(string: "about:blank"))
        pages.select(session: presented(session))
        let activeLease = try XCTUnwrap(
            pages.makeTransientPageLease(url: url, in: space)
        )
        // `dispatch_source_get_data` is only defined for the duration of the
        // event handler, so the level has to be captured there and passed in as a
        // value. Reading it back off the source after a hop is what made every
        // squeeze — critical included — arrive here as a warning.

        pages.handleMemoryPressureEvent([.warning])

        XCTAssertNotNil(
            activeLease.page,
            "A warning deliberately preserves the transient surface in use."
        )

        pages.handleMemoryPressureEvent([.critical])

        XCTAssertNil(
            activeLease.page,
            "Critical pressure must reach critical handling instead of collapsing to a warning."
        )
        XCTAssertTrue(activeLease.wasReleasedForMemoryPressure)
        XCTAssertNotNil(pages.activePage)
    }

    // MARK: - Split View presentation

    func testSelectingAMemberPresentsTheWholeRunWithThatMemberFocused() throws {
        let split = makeSplitSession(memberCount: 3, selectedIndex: 1)
        let pages = makeSplitPageStore(for: split.session)

        pages.select(session: split.session)

        XCTAssertEqual(pages.presentedTabIDs, split.memberIDs)
        XCTAssertEqual(pages.activePage?.tabID, split.memberIDs[1])
        XCTAssertEqual(
            pages.residentPageCount,
            1,
            """
            Only the focused member is built by selection. The carousel asks for \
            its neighbours as their cells materialize, which is what keeps a \
            four-member group off four live web views on a phone.
            """
        )
    }

    func testPreparingACardRefusesTabsOutsideTheSelectedSpace() throws {
        let split = makeSplitSession(memberCount: 2, selectedIndex: 0)
        let otherSpace = makeSpace(index: 21, savesCredentials: true)
        let session = BrowserPresentedSession(
            session: BrowserSession(spaces: [try XCTUnwrap(split.session.selectedSpace), otherSpace]),
            window: split.session.window
        )
        let pages = makeSplitPageStore(for: session)
        pages.select(session: session)

        XCTAssertNil(
            pages.prepareResidentPage(
                for: try XCTUnwrap(otherSpace.tabs.first?.id),
                in: session
            ),
            "A card only ever belongs to the selected Space."
        )
        XCTAssertNil(
            pages.prepareResidentPage(
                for: fixedUUID(0xDEAD),
                in: session
            )
        )
    }

    func testResidentPageAccessorRefusesNonMembersAndMismatchedAssignments() throws {
        let split = makeSplitSession(memberCount: 2, selectedIndex: 0)
        let space = try XCTUnwrap(split.session.selectedSpace)
        let pages = makeSplitPageStore(for: split.session)
        pages.select(session: split.session)
        pages.prepareResidentPage(for: split.memberIDs[1], in: split.session)

        XCTAssertNotNil(
            pages.residentPage(
                matching: BrowserTabRuntimeAssignment(
                    tabID: split.memberIDs[1],
                    spaceID: space.id,
                    profileID: space.profile.id
                )
            )
        )
        XCTAssertNil(
            pages.residentPage(
                matching: BrowserTabRuntimeAssignment(
                    tabID: split.memberIDs[1],
                    spaceID: space.id,
                    profileID: fixedUUID(0xBEEF)
                )
            ),
            """
            Binding a page across a profile boundary is exactly the isolation \
            failure per-Space browsing exists to prevent.
            """
        )
        XCTAssertNil(
            pages.residentPage(
                matching: BrowserTabRuntimeAssignment(
                    tabID: split.nonMemberID,
                    spaceID: space.id,
                    profileID: space.profile.id
                )
            ),
            "A background tab with a resident page is not a card."
        )
    }

    // MARK: - Helpers

    /// A Space holding one split run plus one ordinary background tab after it.
    private func makeSplitSession(
        memberCount: Int,
        selectedIndex: Int
    ) -> SplitFixture {
        let groupID = fixedUUID(0x5000)
        let members = (0..<memberCount).map { index in
            BrowserTab(
                id: fixedUUID(0x5100 + index),
                title: "Card \(index)",
                url: URL(string: "https://cards.crest.test/\(index)"),
                placement: .current,
                splitGroupID: groupID,
                lastActivatedAt: fixedDate(index)
            )
        }
        let background = BrowserTab(
            id: fixedUUID(0x5200),
            title: "Background",
            url: URL(string: "https://background.crest.test"),
            placement: .current,
            lastActivatedAt: fixedDate(0)
        )
        let space = BrowserSpace(
            id: fixedUUID(0x5300),
            profile: BrowsingProfile(id: fixedUUID(0x5400)),
            name: "Split",
            symbol: "rectangle.split.2x1",
            accent: .indigo,
            folders: [],
            tabs: members + [background]
        )
        return SplitFixture(
            session: presented(BrowserSession(spaces: [space]), showing: members[selectedIndex].id),
            memberIDs: members.map(\.id),
            nonMemberID: background.id
        )
    }

    private func makeSplitPageStore(for session: BrowserPresentedSession) -> MobileBrowserPageStore {
        MobileBrowserPageStore(browser: .hostingPages(session.session), usesEphemeralWebsiteDataStores: true)
    }

    private func makeLinkRoutingPageStore(
        browser: BrowserStore
    ) -> MobileBrowserPageStore {
        MobileBrowserPageStore(
            browser: browser,
            usesEphemeralWebsiteDataStores: true,
            openModifiedLink: { url, spaceID, selecting in
                guard
                    let tabID = browser.openNewTab(
                        url: url,
                        in: spaceID,
                        selecting: selecting
                    ),
                    let space = browser.session.space(id: spaceID),
                    let tab = space.tabs.first(where: { $0.id == tabID })
                else { return nil }
                return BrowserModifiedLinkRegistration(tab: tab, space: space, session: browser.presented)
            }
        )
    }

    /// The window view of `session`: its first Space showing `tabID`, or that
    /// Space's first tab.
    private func presented(_ session: BrowserSession, showing tabID: TabID? = nil) -> BrowserPresentedSession {
        guard let space = session.spaces.first, let shown = tabID ?? space.tabs.first?.id else {
            preconditionFailure("Page store fixtures always hold a Space with a tab.")
        }
        return BrowserPresentedSession(
            session: session,
            window: .preview(showing: space.id, tabs: [space.id: shown])
        )
    }

    private func fixedDate(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + Double(offset))
    }

    private func makeSession(
        index: Int,
        savesCredentials: Bool = true
    ) -> BrowserSession {
        let space = makeSpace(index: index, savesCredentials: savesCredentials)
        return BrowserSession(spaces: [space])
    }

    private func makeSpace(
        index: Int,
        savesCredentials: Bool
    ) -> BrowserSpace {
        let tab = BrowserTab.startPage(
            id: fixedUUID(index * 10 + 1),
            placement: .current
        )
        var credentialPreferences = BrowserCredentialPreferences.default
        credentialPreferences.isEnabled = savesCredentials
        return BrowserSpace(
            id: fixedUUID(index * 10 + 2),
            profile: BrowsingProfile(id: fixedUUID(index * 10 + 3)),
            name: "Space \(index)",
            symbol: "circle",
            accent: .indigo,
            folders: [],
            tabs: [tab],
            credentialPreferences: credentialPreferences
        )
    }

    private func submitMessage() throws -> BrowserCredentialFormMessage {
        try message([
            "version": 1,
            "event": "submit",
            "trusted": true,
            "formID": "login-form",
            "username": "person@example.com",
            "password": "secret-value",
            "passwordKind": "current",
        ])
    }

    private func documentStateMessage() throws -> BrowserCredentialFormMessage {
        try message([
            "version": 1,
            "event": "documentState",
            "trusted": true,
            "hasVisiblePasswordField": false,
        ])
    }

    private func message(_ body: [String: Any]) throws -> BrowserCredentialFormMessage {
        try XCTUnwrap(BrowserCredentialFormMessage(body: body))
    }

    private func waitUntil(
        timeout: Duration = .seconds(8),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for the browser state to change.")
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func assertThrowsErrorAsync(
        _ expression: @autoclosure () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected the call to throw.", file: file, line: line)
        } catch {}
    }

    private func fixedUUID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", value))!
    }
}

/// One split run, its members in order, and the background tab that follows it.
private struct SplitFixture {
    let session: BrowserPresentedSession
    let memberIDs: [TabID]
    let nonMemberID: TabID
}
