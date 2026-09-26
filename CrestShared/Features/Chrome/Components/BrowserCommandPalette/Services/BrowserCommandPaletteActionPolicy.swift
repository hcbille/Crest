/// Whether a palette or Start Page action still speaks for what the window
/// shows: its source tab must be the one the window shows, in an unlocked
/// Space of the same profile, and its target a tab of that Space.
@MainActor
enum BrowserCommandPaletteActionPolicy {
    // MARK: - Actions - Validating

    static func isSourceAvailable(
        _ source: BrowserTabRuntimeAssignment,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> Bool {
        selectedSource(matching: source, in: browser, accessController: accessController) != nil
    }

    static func target(
        _ target: BrowserTabRuntimeAssignment,
        from source: BrowserTabRuntimeAssignment,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> (space: SpaceModel, tab: TabStateModel)? {
        guard target.spaceID == source.spaceID, target.profileID == source.profileID,
            let (space, _) = selectedSource(matching: source, in: browser, accessController: accessController),
            let tab = space.tabs.model(target.tabID)
        else { return nil }
        return (space, tab)
    }

    private static func selectedSource(
        matching source: BrowserTabRuntimeAssignment,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> (space: SpaceModel, tab: TabStateModel)? {
        guard
            let space = BrowserSidebarAccessPolicy.selectedUnlockedSpace(
                matching: BrowserSpaceRuntimeAssignment(spaceID: source.spaceID, profileID: source.profileID),
                in: browser, accessController: accessController),
            browser.selectedTabID(in: space.id) == source.tabID,
            let tab = space.tabs.model(source.tabID)
        else { return nil }
        return (space, tab)
    }
}
