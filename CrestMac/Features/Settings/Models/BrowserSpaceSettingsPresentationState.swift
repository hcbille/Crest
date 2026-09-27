import Foundation
import Observation

@Observable
@MainActor
final class BrowserSpaceSettingsPresentationState {
    private(set) var requestedDestination = BrowserSettingsDestination.spaces
    private(set) var requestedAssignment: BrowserSpaceRuntimeAssignment?
    private(set) var revision = 0

    var requestedSpaceID: UUID? { requestedAssignment?.spaceID }

    func present(assignment: BrowserSpaceRuntimeAssignment) {
        present(.spaces, assignment: assignment)
    }

    func present(
        _ destination: BrowserSettingsDestination,
        assignment: BrowserSpaceRuntimeAssignment
    ) {
        requestedDestination = destination
        requestedAssignment = assignment
        revision &+= 1
    }

    func requestedSpaceID(in browser: BrowserStore) -> UUID? {
        guard let requestedAssignment else { return nil }
        return browser.spaceModel(matching: requestedAssignment)?.id
    }
}
