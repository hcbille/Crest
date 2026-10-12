import SwiftUI

enum BrowserSidebarPresentationPolicy {
    static let floatingCardInset: CGFloat = 7
    static let floatingCardCornerRadius: CGFloat = 18

    static func floatingHoverRegionWidth(sidebarWidth: CGFloat) -> CGFloat {
        sidebarWidth + (floatingCardInset * 2)
    }

    static func presentation(
        columnVisibility: NavigationSplitViewVisibility,
        isFloatingSidebarPresented: Bool,
        isPageFullscreen: Bool = false
    ) -> BrowserSidebarPresentation {
        // A page alone in full screen has no room beside it, so a docked
        // sidebar can only float over it, and docks again once it ends.
        guard columnVisibility == .detailOnly || isPageFullscreen else { return .docked }
        return isFloatingSidebarPresented ? .floating : .collapsed
    }
}
