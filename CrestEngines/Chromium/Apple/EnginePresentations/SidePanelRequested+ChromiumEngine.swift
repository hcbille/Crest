#if CREST_CHROMIUM_HOST
    import Foundation

    extension SidePanelRequested {
        @MainActor func present(on engine: ChromiumEngine) {
            CrestChromiumRoot.routeSidePanel(self)
        }
    }
#endif
