#if CREST_CHROMIUM_HOST
    import Foundation

    extension InfoBarRemoved {
        @MainActor func present(on engine: ChromiumEngine) {
            engine.presentedPage(pageID)?.observer(.infoBarRemoved(id: Int(infoBarID)))
        }
    }
#endif
