import Foundation

/// Finishes the setup the core holds from a window.
///
/// The core decides what finishing does: it applies the manual setup, marks
/// setup done on the device, and names the Space the Getting Started guide
/// opens in, refusing while that Space is locked. The platform's part is
/// asking the device owner to unlock that Space and trying once more, then
/// opening the guide.
@MainActor
enum BrowserSetupFinish {
    // MARK: - Types

    enum Result: Equatable {
        /// Setup finished, and opened the guide in `guide` when the core asked.
        case completed(guide: BrowserTabRuntimeAssignment?)
        /// The person did not unlock the guide's Space, or the task went.
        case cancelled
        /// The core refused to finish, in its own words.
        case refused(String)
    }

    // MARK: - Actions - Finishing

    /// Finishes setup from `browser`'s window, unlocking the guide's Space
    /// through `spaceAccess` when the core asks for it.
    static func finish(browser: BrowserStore, spaceAccess: BrowserSpaceAccessController) async -> Result {
        guard !Task.isCancelled else { return .cancelled }
        let finishing = FinishSetup(windowID: browser.windowID)
        do {
            return completed(try browser.family.commit(finishing, from: browser), in: browser)
        } catch let rejection {
            guard case .guideSpaceLocked(let locked) = rejection, let space = browser.spaceModel(locked.spaceID)
            else { return .refused(rejection.explanation) }
            guard await spaceAccess.unlock(space), !Task.isCancelled else { return .cancelled }
            do {
                return completed(try browser.family.commit(finishing, from: browser), in: browser)
            } catch {
                return .refused(error.explanation)
            }
        }
    }

    /// Opens the guide where the core's finish names it.
    private static func completed(_ changes: [Change], in browser: BrowserStore) -> Result {
        let finished = changes.lazy.compactMap { change -> SetupFinished? in
            if case .setupFinished(let finished) = change { return finished }
            return nil
        }.first
        guard let spaceID = finished?.guideSpaceID, let space = browser.spaceModel(spaceID) else {
            return .completed(guide: nil)
        }
        return .completed(
            guide: browser.openGettingStartedAfterSetup(
                matching: BrowserSpaceRuntimeAssignment(spaceID: space.id, profileID: space.profileID)))
    }
}
