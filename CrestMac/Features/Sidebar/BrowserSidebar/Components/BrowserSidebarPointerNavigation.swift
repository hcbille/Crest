import SwiftUI

struct BrowserSidebarPointerNavigation: NSViewRepresentable {
    let isSidebarVisible: Bool
    let perform: @MainActor @Sendable (BrowserSidebarMouseButtonAction) -> Void
    let navigationTargets: @MainActor @Sendable () -> [any BrowserSidebarMouseNavigationTarget]

    func makeNSView(context: Context) -> BrowserSidebarPointerNavigationView {
        let view = BrowserSidebarPointerNavigationView(
            perform: perform,
            navigationTargets: navigationTargets
        )
        view.isHidden = !isSidebarVisible
        return view
    }

    func updateNSView(
        _ nsView: BrowserSidebarPointerNavigationView,
        context: Context
    ) {
        nsView.perform = perform
        nsView.navigationTargets = navigationTargets
        nsView.isHidden = !isSidebarVisible
        nsView.answerForWindow()
    }
}
