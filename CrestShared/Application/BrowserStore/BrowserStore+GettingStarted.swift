import Foundation

extension BrowserStore {
    /// Closing a saved native view dismisses its presentation, retaining the
    /// document in Saved. Current copies continue through the normal close path.
    func dismissNativeTab(_ id: TabID, matching assignment: BrowserSpaceRuntimeAssignment) {
        guard let space = shownSpace, BrowserSpaceRuntimeAssignment(space: space) == assignment,
            selectedTabID(in: space.id) == id,
            space.tabs.model(id)?.nativeContent != nil
        else { return }
        selectDismissalFallback(afterDismissing: id)
    }

    @discardableResult
    func openGettingStarted() -> TabID? {
        if let existing = shownSpace?.tabs.models.first(where: { $0.nativeTabContent == .gettingStarted }) {
            selectTab(existing.id)
            return existing.id
        }
        return openNativeTab(.gettingStarted, title: String(localized: "Getting Started"), symbol: "book.closed.fill")
    }

    @discardableResult
    func openGettingStartedAfterSetup(matching assignment: BrowserSpaceRuntimeAssignment)
        -> BrowserTabRuntimeAssignment?
    {
        guard !isPrivateBrowsing, let firstSpace = spaceModels.first,
            BrowserSpaceRuntimeAssignment(space: firstSpace) == assignment
        else { return nil }
        selectSpace(firstSpace.id)
        guard let tabID = openGettingStarted() else { return nil }
        return BrowserTabRuntimeAssignment(tabID: tabID, spaceID: assignment.spaceID, profileID: assignment.profileID)
    }

    /// Settings is one ordinary, closable native tab per Space. Repeated menu
    /// commands focus that tab without creating duplicates or opening WebKit.
    @discardableResult
    func openSettings() -> TabID? {
        if let existing = shownSpace?.tabs.models.first(where: { $0.nativeTabContent == .settings }) {
            selectTab(existing.id)
            return existing.id
        }
        return openNativeTab(
            .settings, title: String(localized: "Settings"), symbol: "gearshape.fill", placement: .current)
    }

    /// Native documents enter the same session mutation and persistence path as
    /// websites. No page pool or second selection model is owned by the document.
    @discardableResult
    func openNativeTab(
        _ content: BrowserNativeTabContent, title: String, symbol: String, placement: TabPlacement = .saved
    ) -> TabID? {
        guard let space = shownSpace else { return nil }
        return openSessionTab(.view(content, title: title, symbol: symbol), in: space.id, placement: placement)
    }
}
