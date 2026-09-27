import Foundation

struct BrowserSidebarClearHistoryConfirmation: Equatable, Sendable {
    let assignment: BrowserSpaceRuntimeAssignment
    let spaceName: String

    var spaceID: UUID { assignment.spaceID }
}
