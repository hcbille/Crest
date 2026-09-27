#if CREST_CHROMIUM_HOST
    import Foundation

    extension PageLoadingChanged {
        @MainActor func present(on engine: ChromiumEngine) {
            guard let page = engine.presentedPage(pageID) else { return }
            page.observer(.loadingChanged(isLoading))
            page.observer(.progressChanged(isLoading ? 0.5 : 1))
        }
    }
#endif
