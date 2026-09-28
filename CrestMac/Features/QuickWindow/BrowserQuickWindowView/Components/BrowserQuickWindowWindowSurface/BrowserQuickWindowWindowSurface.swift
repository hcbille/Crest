import SwiftUI

struct BrowserQuickWindowWindowSurface: View {
    let model: BrowserQuickWindowModel
    let spaceAccess: BrowserSpaceAccessController
    let pagePoolRegistry: BrowserPagePoolRegistry?
    let dismiss: () -> Void
    let openBrowserWindow: () -> Void

    var body: some View {
        BrowserQuickWindowContent(
            model: model,
            spaceAccess: spaceAccess,
            dismiss: closeItself,
            openBrowserWindow: openBrowserWindow
        )
        .modifier(BrowserQuickWindowAppearanceModifier(model: model))
        .onChange(of: selectedSpaceIsLocked, initial: true) { _, isLocked in
            if isLocked {
                model.releaseForUnavailableSpace()
            }
        }
        .background {
            BrowserQuickWindowGeometryBridge(
                pagePoolRegistry: pagePoolRegistry,
                targetWindowID: model.presentedRequest.targetWindowID
            )
        }
        .background {
            BrowserMacWindowAttachment(
                closeGate: model.closeGate, attach: { _ in }, focusChanged: { _ in }, close: {}
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .background {
            BrowserNativeWindowControlsBridge(isVisible: true)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onDisappear(perform: model.releaseForDismissal)
    }

    /// Every close the window's content asks for is the window closing
    /// itself: its page closed, moved to a tab or went to the archive.
    private func closeItself() {
        model.closeItself()
        dismiss()
    }

    private var selectedSpaceIsLocked: Bool {
        guard let space = model.spaceModel else { return false }
        return spaceAccess.isLocked(space)
    }
}
