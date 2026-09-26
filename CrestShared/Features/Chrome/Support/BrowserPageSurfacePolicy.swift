import CoreGraphics

enum BrowserPageSurfacePolicy {
    static let startPageUsesSpaceAtmosphere = true
    static let startPageUsesTransparentInnerSurface = true
    static let shadowOpacity = 0.11
    static let shadowRadius: CGFloat = 7
    static let shadowYOffset: CGFloat = 2
    static let shadowDrawingOutset = shadowRadius * 2 + abs(shadowYOffset)
    static let boundaryStrokeWidth: CGFloat = 0.5
    static let boundaryStrokeOpacity = CrestOpacity.border

    static func usesTransparentInnerSurface(
        isStartPage: Bool,
        hasActivePage: Bool,
        completedNavigationCount: Int
    ) -> Bool {
        (startPageUsesSpaceAtmosphere
            && startPageUsesTransparentInnerSurface
            && isStartPage)
            || !hasActivePage
            || completedNavigationCount == 0
    }

    static func revealsWebContent(committedNavigationCount: Int) -> Bool {
        committedNavigationCount > 0
    }

    static func isNavigating(
        isLoading: Bool,
        hasPendingNavigation: Bool,
        committedNavigationCount: Int
    ) -> Bool {
        // Same-document destinations can remain pending without a WebKit load.
        // Only use the destination to bridge a fresh page's initial loading gap.
        isLoading || (hasPendingNavigation && committedNavigationCount == 0)
    }

    static func showsInitialLoadingStatus(
        isNavigating: Bool,
        committedNavigationCount: Int,
        hasFailure: Bool
    ) -> Bool {
        isNavigating && committedNavigationCount == 0 && !hasFailure
    }

    static func loadingProgress(
        estimatedProgress: Double,
        isNavigating: Bool
    ) -> CGFloat {
        guard isNavigating else { return 0 }
        return CGFloat(min(max(estimatedProgress, 0.04), 1))
    }
}
