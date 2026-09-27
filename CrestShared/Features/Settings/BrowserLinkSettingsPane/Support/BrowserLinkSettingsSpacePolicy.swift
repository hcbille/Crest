import Foundation

enum BrowserLinkSettingsSpacePolicy {
    /// The Space links open in: the preferred one while it is available, then
    /// the selected one, then the first available Space.
    @MainActor
    static func resolvedExternalSpaceID(
        preferredSpaceID: UUID?,
        spaces: [SpaceModel],
        selectedSpaceID: UUID
    ) -> UUID {
        if let preferredSpaceID, spaces.contains(where: { $0.id == preferredSpaceID }) {
            return preferredSpaceID
        }
        if spaces.contains(where: { $0.id == selectedSpaceID }) {
            return selectedSpaceID
        }
        return spaces.first?.id ?? selectedSpaceID
    }
}
