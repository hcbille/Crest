import Foundation

@testable import Crest

/// What a window shows, as values read from `snapshot`, for tests.
extension BrowserStore {
    /// The Space this window shows, as `snapshot` holds it.
    var shownSpaceState: SpaceState? {
        snapshot.space(id: window.shownSpaceID)
    }

}
