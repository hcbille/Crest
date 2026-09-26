#if CREST_CHROMIUM_HOST
import Foundation

@MainActor
struct ChromiumProfileRemover: BrowserEngineProfileRemoving {
    let engine: ChromiumEngine

    func removeProfile(_ profile: BrowsingProfile, ephemeral: Bool) async throws {
        guard await engine.deleteProfile(profile.id, ephemeral: ephemeral) else { throw RemovalError.failed }
    }

    private enum RemovalError: LocalizedError {
        case failed
        var errorDescription: String? { "Chromium couldn’t finish removing this Space’s browser data. Try again." }
    }
}
#endif
