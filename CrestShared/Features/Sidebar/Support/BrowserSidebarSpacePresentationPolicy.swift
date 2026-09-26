@MainActor
enum BrowserSidebarSpacePresentationPolicy {
    static func clearHistoryConfirmation(
        for space: SpaceModel,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> BrowserSidebarClearHistoryConfirmation? {
        let assignment = BrowserSpaceRuntimeAssignment(space: space)
        guard
            BrowserSidebarAccessPolicy.selectedUnlockedSpace(
                matching: assignment,
                in: browser,
                accessController: accessController
            ) != nil
        else { return nil }
        return BrowserSidebarClearHistoryConfirmation(
            assignment: assignment,
            spaceName: space.settings.name
        )
    }

    static func isLive(
        _ confirmation: BrowserSidebarClearHistoryConfirmation,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> Bool {
        BrowserSidebarAccessPolicy.selectedUnlockedSpace(
            matching: confirmation.assignment,
            in: browser,
            accessController: accessController
        ) != nil
    }

    @discardableResult
    static func clearHistory(
        _ confirmation: BrowserSidebarClearHistoryConfirmation,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> Bool {
        guard
            isLive(
                confirmation,
                in: browser,
                accessController: accessController
            )
        else { return false }
        return browser.clearHistory(matching: confirmation.assignment)
    }
}
