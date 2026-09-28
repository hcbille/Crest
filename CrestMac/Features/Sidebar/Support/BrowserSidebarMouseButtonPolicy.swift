import CoreGraphics

enum BrowserSidebarMousePointerScope: Equatable {
    case webpage
    case sidebar
    case unowned
}

enum BrowserSidebarMouseButtonDisposition: Equatable {
    case navigatePage(BrowserSidebarMouseButtonAction)
    case switchSpace(BrowserSidebarMouseButtonAction)
    case consume
}

enum BrowserSidebarMouseButtonPolicy {
    static func action(for buttonNumber: Int) -> BrowserSidebarMouseButtonAction? {
        switch buttonNumber {
        case 3:
            .previousSpace
        case 4:
            .nextSpace
        default:
            nil
        }
    }

    /// A swipe no page took goes back when it moves right, a positive
    /// `deltaX`, and forward when it moves left, as WebKit's views and
    /// Chrome's windows read it. A vertical swipe does neither.
    static func action(forSwipeDeltaX deltaX: CGFloat) -> BrowserSidebarMouseButtonAction? {
        if deltaX > 0 { return .previousSpace }
        if deltaX < 0 { return .nextSpace }
        return nil
    }

    static func disposition(
        for action: BrowserSidebarMouseButtonAction,
        pointerScope: BrowserSidebarMousePointerScope,
        canNavigatePage: Bool
    ) -> BrowserSidebarMouseButtonDisposition? {
        switch pointerScope {
        case .webpage:
            canNavigatePage ? .navigatePage(action) : .consume
        case .sidebar:
            .switchSpace(action)
        case .unowned:
            nil
        }
    }
}
