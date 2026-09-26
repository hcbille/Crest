import Foundation

struct BrowserTabRuntimeAssignment: Equatable, Hashable, Sendable {
    let tabID: TabID
    let spaceID: SpaceID
    let profileID: UUID

    /// Where the tab's Space lives: its identity and profile.
    var spaceAssignment: BrowserSpaceRuntimeAssignment {
        BrowserSpaceRuntimeAssignment(spaceID: spaceID, profileID: profileID)
    }
}
