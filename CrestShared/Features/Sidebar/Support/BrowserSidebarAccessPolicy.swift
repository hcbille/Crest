/// Which Spaces of a window's workspace its chrome may show and act on, read
/// from the core's read model: every Space not being deleted, and of those,
/// the ones this process holds the grant to show.
@MainActor
enum BrowserSidebarAccessPolicy {
    // MARK: - Actions - Spaces

    static func availableSpaces(in browser: BrowserStore) -> [SpaceModel] {
        browser.spaceModels.filter { !browser.isDeleting($0.id) }
    }

    static func unlockedSpace(
        matching assignment: BrowserSpaceRuntimeAssignment,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> SpaceModel? {
        guard !browser.isDeleting(assignment.spaceID), let space = browser.spaceModel(assignment.spaceID),
            space.profileID == assignment.profileID, !accessController.isLocked(space)
        else { return nil }
        return space
    }

    static func selectedUnlockedSpace(
        matching assignment: BrowserSpaceRuntimeAssignment,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> SpaceModel? {
        guard browser.selectedSpaceID == assignment.spaceID else { return nil }
        return unlockedSpace(matching: assignment, in: browser, accessController: accessController)
    }

    static func showsSelectedSpaceActions(
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> Bool {
        guard let space = browser.shownSpace else { return false }
        return !accessController.isLocked(space)
    }

    static func availableTabMoveDestinationSpaces(
        from sourceAssignment: BrowserSpaceRuntimeAssignment,
        in browser: BrowserStore,
        accessController: BrowserSpaceAccessController
    ) -> [SpaceModel] {
        guard selectedUnlockedSpace(matching: sourceAssignment, in: browser, accessController: accessController) != nil
        else { return [] }
        return availableSpaces(in: browser).filter { space in
            space.id != sourceAssignment.spaceID && !accessController.isLocked(space)
        }
    }
}
