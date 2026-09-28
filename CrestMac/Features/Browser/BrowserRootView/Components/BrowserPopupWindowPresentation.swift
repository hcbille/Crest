import SwiftUI

/// Gives a window's page pool the way to open the Quick Window that shows a
/// window one of its pages asked for, such as a sign-in popup: the process
/// host's own windows when it presents them, and otherwise the Quick Window
/// scene.
struct BrowserPopupWindowPresentation: ViewModifier {
    let pages: BrowserPagePool

    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            let openWindow = openWindow
            pages.popupWindowPresenter = { request in
                if let host = BrowserMacWindowPresentation.host {
                    host.openQuickWindow(request)
                } else {
                    openWindow(id: BrowserSceneID.quickWindow.rawValue, value: request)
                }
            }
        }
    }
}
