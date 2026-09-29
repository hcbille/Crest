import SwiftUI

extension EnvironmentValues {
    @Entry var browserPagePresentationWindowID: UUID? = nil
    @Entry var browserWebFocusRestorationGate =
        BrowserWebFocusRestorationGate.suppressed
}

struct BrowserPlatformWebView: NSViewRepresentable {
    @Environment(\.browserPagePresentationWindowID) private var presentationWindowID
    /// Whether the window shows the Space this page is drawn in.
    @Environment(\.spaceContentIsInteractive) private var presentsPage
    let page: BrowserPage
    let isPageActive: Bool
    let focusRestorationGate: BrowserWebFocusRestorationGate

    func makeNSView(context: Context) -> BrowserWebHostView {
        let host = BrowserWebHostView()
        host.updatePresentation(presentsPage: presentsPage)
        host.attach(
            page.nativeView,
            focusRestoration: page.focusRestoration,
            allowsAttachment: allowsAttachment
        )
        host.updateFocusPresentation(
            isPageActive: isPageActive,
            gate: focusRestorationGate
        )
        return host
    }

    func updateNSView(_ host: BrowserWebHostView, context: Context) {
        host.attach(
            page.nativeView,
            focusRestoration: page.focusRestoration,
            allowsAttachment: allowsAttachment
        )
        host.updateFocusPresentation(
            isPageActive: isPageActive,
            gate: focusRestorationGate
        )
        // After the attachment, so a page that arrives with its Space comes
        // on screen once, and with the focus the update just settled.
        host.updatePresentation(presentsPage: presentsPage)
    }

    static func dismantleNSView(_ host: BrowserWebHostView, coordinator: Void) {
        host.detach()
    }

    private var allowsAttachment: Bool {
        guard let presentationWindowID, let owner = page.windowRouting?.pool else { return true }
        return owner.windowID == presentationWindowID
    }
}
