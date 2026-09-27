#if CREST_CHROMIUM_HOST
    import SwiftUI

    extension BrowserEngineRegistration {
        /// Selected by the process composition, never by synced Space records.
        static var current: BrowserAdapterRegistration { chromium }

        @MainActor
        static func featureFlagsPane(space: SpaceModel?, browser: BrowserStore) -> some View {
            BrowserChromiumFeatureFlagSettingsPane(space: space, browser: browser)
        }
    }
#endif
