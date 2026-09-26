import Foundation

/// The Space values the Chromium extension views still take.
extension BrowserStore {
    // MARK: - Actions - Reading

    /// The Space as the session copy holds it, for the engine-contributed
    /// extension views that take one. TRANSITIONAL until Lane 2 moves the
    /// Chromium extension views to the read model; every other view reads
    /// `spaceModel(_:)`.
    func engineSpace(_ spaceID: SpaceID) -> BrowserSpace? {
        guard !isDeleting(spaceID) else { return nil }
        return session.space(id: spaceID)
    }
}
