import SwiftUI

struct BrowserRootCommandPaletteLayer: View {
    let model: BrowserRootModel
    let shortcuts: BrowserShortcutStore?
    let commandSurfaceNamespace: Namespace.ID
    var contentInsets = EdgeInsets()

    @Environment(\.openWindow) private var openWindow
    @Environment(\.layoutDirection) private var layoutDirection

    @ViewBuilder
    var body: some View {
        if let mode = model.chrome.commandPaletteMode,
            model.isCommandPaletteShown
        {
            BrowserCommandPalette(
                browser: model.browser,
                space: paletteSpace,
                selectedTabID: model.browser.shownTab?.id,
                initialQuery: mode.initialQuery,
                commands: model.paletteRegistry(
                    openWindow: openWindow, layoutDirection: layoutDirection, shortcuts: shortcuts),
                isSourceAvailable: model.isPaletteSourceAvailable,
                selectTab: model.selectPaletteTab,
                openURL: { source, url in
                    model.openPaletteURL(url, mode: mode, from: source)
                },
                dismiss: model.chrome.dismissCommandPalette,
                morphNamespace: commandSurfaceNamespace,
                overlayContentInsets: contentInsets,
                emptySelectionActions: model.emptySelectionPaletteActions
            )
            .id(
                BrowserCommandPalettePresentationIdentity(
                    mode: mode,
                    space: paletteSpace,
                    source: model.selectedTabAssignment
                )
            )
            .transition(.browserCommandPaletteOverlay)
            .zIndex(BrowserRootMetrics.commandPaletteZIndex)
        }
    }

    /// The Space the window shows, unless it is being deleted.
    private var paletteSpace: SpaceModel? {
        model.browser.shownSpace
    }
}
