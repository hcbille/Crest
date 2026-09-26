import Foundation

/// The Space values the engines and the Chromium extension views still take.
extension BrowserStore {
    // MARK: - Variables

    /// The Space this window shows as the session copy holds it, or nil while
    /// it is being deleted. TRANSITIONAL until Lane 2's page hosts and the
    /// tests read `shownSpace`.
    var selectedSpace: BrowserSpace? {
        engineSpace(selectedSpaceID)
    }

    /// The tab this window shows as the session copy holds it. TRANSITIONAL
    /// until Lane 2's page hosts and the tests read `shownTab`.
    var selectedTab: BrowserTab? {
        guard let space = selectedSpace, let tabID = selectedTabID(in: space.id) else { return nil }
        return space.tabs.first { $0.id == tabID }
    }

    // MARK: - Actions - Reading

    /// The Space as the session copy holds it, for the engine-contributed
    /// extension views that take one. TRANSITIONAL until Lane 2 moves the
    /// Chromium extension views to the read model; every other view reads
    /// `spaceModel(_:)`.
    func engineSpace(_ spaceID: SpaceID) -> BrowserSpace? {
        guard !isDeleting(spaceID) else { return nil }
        return session.space(id: spaceID)
    }

    /// The Space `assignment` names as the session copy holds it, while this
    /// device is not deleting it and it keeps that profile. TRANSITIONAL until
    /// Lane 2's page hosts and the Chromium views read the read model; every
    /// other rule reads `spaceModel(matching:)`.
    func space(matching assignment: BrowserSpaceRuntimeAssignment) -> BrowserSpace? {
        guard let space = engineSpace(assignment.spaceID), assignment.matches(space) else { return nil }
        return space
    }
}
