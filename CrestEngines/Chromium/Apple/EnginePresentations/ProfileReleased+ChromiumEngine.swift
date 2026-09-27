#if CREST_CHROMIUM_HOST
    import Foundation

    extension ProfileReleased {
        @MainActor func present(on engine: ChromiumEngine) {
            CrestChromiumRoot.profileReleased(self)
        }
    }
#endif
