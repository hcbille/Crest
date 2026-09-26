import Foundation

@MainActor
struct BrowserDurableTabCloseAction {
    let browser: BrowserStore
    let spaceAccess: BrowserSpaceAccessController
    var preferences: BrowserAppPreferenceStore = .shared
    /// Retires only the matching page. False means another runtime owns it.
    let closePage: (BrowserTabRuntimeAssignment, Bool) -> Bool

    func perform(_ assignment: BrowserTabRuntimeAssignment) -> Bool {
        guard
            let space = BrowserSidebarAccessPolicy.selectedUnlockedSpace(
                matching: BrowserSpaceRuntimeAssignment(spaceID: assignment.spaceID, profileID: assignment.profileID),
                in: browser, accessController: spaceAccess
            ), let tab = space.tabs.model(assignment.tabID),
            tab.placement.isDurable
        else { return false }
        // The core asks the page whether it may go first. TRANSITIONAL until
        // the shared page host follows the core's page closes (WP C (j2)): the
        // engine then closes the page, keeping its state only when the core
        // will leave the tab where it is, which the same preference says.
        let returnsToRoot = preferences.savedTabClosePolicy == .returnToSavedURL && (tab.savedURL ?? tab.url) != nil
        return browser.performPageDismissal(of: [assignment]) {
            guard
                BrowserSidebarAccessPolicy.selectedUnlockedSpace(
                    matching: BrowserSpaceRuntimeAssignment(
                        spaceID: assignment.spaceID, profileID: assignment.profileID),
                    in: browser, accessController: spaceAccess) != nil,
                closePage(assignment, returnsToRoot)
            else { return false }
            return browser.closeDurableTab(assignment)
        }
    }
}
