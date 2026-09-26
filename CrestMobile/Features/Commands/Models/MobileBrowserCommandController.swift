import SwiftUI

@MainActor
struct MobileBrowserCommandController {
    let browser: BrowserStore
    let pages: MobileBrowserPageStore
    var spaceAccess = BrowserSpaceAccessController()
    var preferences: BrowserAppPreferenceStore = .shared

    // MARK: - Variables

    /// How many tabs the Space this window shows holds.
    var tabCount: Int {
        browser.shownSpace?.tabs.models.count ?? 0
    }

    var canArchiveSelectedTab: Bool {
        browser.allows(.archiveTab)
    }

    var canDismissSelectedTab: Bool {
        guard let tab = browser.shownTab, let space = browser.shownSpace else { return false }
        return !browser.closingLeavesOnlyTheWindow(tab.id, in: space.id)
    }

    var canDuplicateSelectedTab: Bool {
        browser.allows(.duplicateTab)
    }

    var canReopenClosedTab: Bool {
        browser.allows(.reopenClosedTab)
    }

    // MARK: - Actions - Tabs

    @discardableResult
    func toggleSelectedTabPinned() -> TabID? {
        guard let tab = browser.shownTab, browser.togglePin(tab.id) else { return nil }
        synchronizePages()
        return tab.id
    }

    @discardableResult
    func archiveSelectedTab() -> TabID? {
        guard let tabID = browser.archiveSelectedTab() else { return nil }
        synchronizePages()
        return tabID
    }

    @discardableResult
    func dismissSelectedTab() -> TabID? {
        guard let selectedTab = browser.shownTab, canDismissSelectedTab else { return nil }
        // TRANSITIONAL until the shared page host follows the core's page
        // closes (WP C (j2)): a saved or pinned tab's page is put away before
        // the core records it.
        if selectedTab.placement.isDurable {
            guard let space = browser.shownSpace,
                BrowserDurableTabCloseAction(
                    browser: browser, spaceAccess: spaceAccess, preferences: preferences,
                    closePage: { pages.closeDurablePage($0, discardState: $1) }
                ).perform(
                    BrowserTabRuntimeAssignment(
                        tabID: selectedTab.id, spaceID: space.id, profileID: space.profileID
                    ))
            else { return nil }
            synchronizePages()
            return selectedTab.id
        }
        if selectedTab.surface == .startPage {
            browser.closeTab(selectedTab.id)
            synchronizePages()
            return selectedTab.id
        }
        return archiveSelectedTab()
    }

    @discardableResult
    func duplicateSelectedTab() -> TabID? {
        guard let tabID = browser.duplicateSelectedTab() else { return nil }
        synchronizePages()
        return tabID
    }

    @discardableResult
    func reopenClosedTab() -> TabID? {
        guard browser.reopenClosedTab() else { return nil }
        synchronizePages()
        return browser.shownTab?.id
    }

    func cleanupCurrentTabs() {
        browser.cleanupCurrentTabs()
        synchronizePages()
    }

    @discardableResult
    func selectPreviousTab() -> TabID? {
        selectAdjacentTab(.previous)
    }

    @discardableResult
    func selectNextTab() -> TabID? {
        selectAdjacentTab(.next)
    }

    @discardableResult
    func selectMostRecentTab() -> TabID? {
        guard browser.showMostRecentTab() else { return nil }
        synchronizePages()
        return browser.shownTab?.id
    }

    /// Shows the tab a numbered command leads to, in the Space this window shows.
    @discardableResult
    func selectNumberedTab(_ tabID: TabID) -> TabID? {
        guard browser.shownSpace?.tabs.model(tabID) != nil else { return nil }
        return selectTab(tabID)
    }

    @discardableResult
    func selectPreviousSpace() -> SpaceID? {
        selectSpace(.previous)
    }

    @discardableResult
    func selectNextSpace() -> SpaceID? {
        selectSpace(.next)
    }

    /// Shows the Space a numbered command leads to.
    @discardableResult
    func selectNumberedSpace(_ spaceID: SpaceID) -> SpaceID? {
        browser.selectSpace(spaceID)
        guard browser.selectedSpaceID == spaceID else { return nil }
        synchronizePages()
        return spaceID
    }

    private func selectAdjacentTab(_ direction: AdjacentDirection) -> TabID? {
        guard let id = browser.selectAdjacentTab(direction) else { return nil }
        synchronizePages()
        return id
    }

    private func selectTab(_ id: TabID) -> TabID? {
        browser.selectTab(id)
        synchronizePages()
        return id
    }

    private func selectSpace(_ direction: BrowserSpaceSwipeDirection) -> SpaceID? {
        guard let id = browser.selectAdjacentSpace(direction) else { return nil }
        synchronizePages()
        return id
    }

    // MARK: - Split View

    var presentedSplitMembers: [TabStateModel] {
        browser.shownCards
    }

    var isSelectedTabInSplit: Bool {
        browser.allows(.separateSplitTabs)
    }

    var canSplitWithNextTab: Bool {
        browser.allows(.splitWithNextTab)
    }

    /// Moves focus one card along the presented run and wraps at both ends.
    ///
    /// Wrapping, unlike the toolbar swipe: a repeated chord reads as cycling
    /// through the cards, where a repeated spatial gesture reads as a direction
    /// and should stop at the edge.
    ///
    /// Focus is selection, so this is `selectTab` and nothing else — the toolbar,
    /// find bar, and every page command follow the pipeline they already followed
    /// before splits existed.
    @discardableResult
    func focusAdjacentSplitCard(offset: Int) -> TabID? {
        let members = presentedSplitMembers
        guard members.count > 1,
            let selectedTabID = browser.shownTab?.id,
            let index = members.firstIndex(where: { $0.id == selectedTabID })
        else { return nil }
        let count = members.count
        let wrappedIndex = (index + offset % count + count) % count
        return selectTab(members[wrappedIndex].id)
    }

    /// Adds the next eligible tab in the selected tab's own section to its split,
    /// creating the group when there is none yet.
    @discardableResult
    func splitWithNextTab() -> TabID? {
        guard let space = browser.shownSpace,
            let selectedTabID = browser.selectedTabID(in: space.id),
            let candidate = browser.nextSplitJoinCandidate,
            browser.addTabToSplit(
                BrowserTabDragItem(tabID: candidate, spaceID: space.id, profileID: space.profileID),
                joining: selectedTabID,
                at: nil
            )
        else { return nil }
        synchronizePages()
        return candidate
    }

    /// Whether the focused card has anywhere to go `offset` slots along its run.
    func canMoveFocusedSplitCard(offset: Int) -> Bool {
        guard let space = browser.shownSpace,
            let selectedTabID = browser.selectedTabID(in: space.id)
        else { return false }
        return browser.canMoveSplitMember(
            selectedTabID,
            by: offset,
            matching: BrowserSpaceRuntimeAssignment(space: space)
        )
    }

    /// Slides the focused card along its run.
    ///
    /// No `synchronizePages()`: the selection and the presented set are both
    /// unchanged, so there is nothing for the pool to reconcile — only the
    /// column order the carousel reads back out of the session.
    @discardableResult
    func moveFocusedSplitCard(offset: Int) -> TabID? {
        guard let space = browser.shownSpace,
            let selectedTabID = browser.selectedTabID(in: space.id),
            browser.moveSplitMember(
                selectedTabID,
                by: offset,
                matching: BrowserSpaceRuntimeAssignment(space: space)
            )
        else { return nil }
        return selectedTabID
    }

    /// Drops the focused card out of its split and leaves it an ordinary tab.
    @discardableResult
    func removeSelectedTabFromSplit() -> TabID? {
        guard let space = browser.shownSpace,
            let selectedTabID = browser.selectedTabID(in: space.id),
            browser.removeTabFromSplit(
                selectedTabID,
                matching: BrowserSpaceRuntimeAssignment(space: space)
            )
        else { return nil }
        synchronizePages()
        return selectedTabID
    }

    /// "Separate All Tabs": every card in the presented split becomes a tab.
    @discardableResult
    func separateSplitTabs() -> TabID? {
        guard let space = browser.shownSpace,
            let selectedTabID = browser.selectedTabID(in: space.id),
            browser.dissolveSplit(
                containing: selectedTabID,
                matching: BrowserSpaceRuntimeAssignment(space: space)
            )
        else { return nil }
        synchronizePages()
        return selectedTabID
    }

    private func synchronizePages() {
        pages.reconcile()
        pages.select()
    }
}
