import Foundation

extension BrowserPlatformPage {
    /// The page's first navigation settled: a document finished, the
    /// navigation failed, or the page stopped loading a document it shows.
    /// An idle page off screen counts its idle time from then.
    var hasSettledNavigation: Bool {
        completedNavigationCount > 0 || live.failure != nil || (live.url != nil && !live.isLoading)
    }

    #if !os(macOS)
    /// TRANSITIONAL until WP C (j1): iPhone and iPad still decide which pages
    /// memory pressure unloads in their page store. The Mac asks the core,
    /// which reads the media each page reports.
    func residencyDecision(isSelected: Bool) async -> BrowserPageResidencyDecision {
        let media = await pageEngine.mediaActivity()
        return BrowserPageResidencyDecision(
            isSelected: isSelected,
            keepsPageLoaded: navigationContext?.keepsPageLoaded == true
                || media?.contains(.pictureInPicture) == true || media == nil,
            isPlayingMedia: media?.contains(.playing) == true,
            isCapturingMedia: media?.contains(.capturing) == true
        )
    }
    #endif
}
