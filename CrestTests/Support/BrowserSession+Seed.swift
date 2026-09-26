import Foundation

@testable import Crest

extension BrowserSession {
    /// The session a first launch starts with, as the core describes it, in
    /// the session copy's values. TRANSITIONAL until the tests that take it
    /// seed with `SessionState.Seed.firstInstall`.
    @MainActor static var firstInstall: BrowserSession {
        do {
            return BrowserSession(core: try CrestCore.answer(FirstInstallSession()), image: { _ in nil })
        } catch {
            preconditionFailure("The core must describe the session a first launch starts with: \(error)")
        }
    }

    /// The session as the core opens it from a seed: repaired as the file's
    /// session is when it loads. Each tab wears the image it carried, and a
    /// tab the repair gave a new identity wears its source's.
    @MainActor func openedAsSeed() throws -> BrowserSession {
        let opened = try BrowserCoreSessionAuthority.open(.persistent, session: self, in: CrestCore())
        defer { opened.close() }
        return opened.projection
    }
}
