import SwiftUI

/// Hands a link or document SwiftUI delivers to this window to the shared
/// external opening, which the core places: never necessarily in this window,
/// but in the frontmost window over the person's own Spaces.
struct BrowserExternalLinkHandler: ViewModifier {
    let externalOpening: BrowserMacExternalOpening
    let coordinator: BrowserMacWindowCoordinator

    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .handlesExternalEvents(
                preferring:
                    BrowserExternalLinkScenePolicy.existingBrowserPreference,
                allowing:
                    BrowserExternalLinkScenePolicy.existingBrowserPreference
            )
            .onOpenURL { url in
                Task { await open(url) }
            }
    }

    private func open(_ url: URL) async {
        let accepted =
            url.isFileURL ? BrowserCorePolicy.acceptsLocalDocument(url) : BrowserCorePolicy.acceptsExternalURL(url)
        guard accepted else { return }
        await externalOpening.open([url], presenter: .scenes(openWindow, coordinator: coordinator))
    }
}

extension BrowserMacExternalOpening.Presenter {
    /// Shows what an open lands in through the SwiftUI composition's scenes: a
    /// browser window already on screen comes forward, and any other opens as
    /// a scene.
    static func scenes(_ openWindow: OpenWindowAction, coordinator: BrowserMacWindowCoordinator) -> Self {
        Self(
            showWindow: { request in
                if let window = coordinator.existingModel(for: request.id)?.window {
                    if window.isMiniaturized { window.deminiaturize(nil) }
                    window.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: BrowserSceneID.browser.rawValue, value: request)
                }
            },
            openQuickWindow: { request in openWindow(id: BrowserSceneID.quickWindow.rawValue, value: request) })
    }
}
