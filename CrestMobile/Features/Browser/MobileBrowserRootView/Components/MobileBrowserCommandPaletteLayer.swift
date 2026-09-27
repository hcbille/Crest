import SwiftUI

struct MobileBrowserCommandPaletteLayer: View {
    let mode: BrowserCommandPaletteMode?
    let browser: BrowserStore
    let space: SpaceModel?
    let selectedTabID: UUID?
    let commands: BrowserCommandPaletteCommandRegistry
    let isSourceAvailable: (BrowserTabRuntimeAssignment) -> Bool
    let selectTab:
        (
            BrowserTabRuntimeAssignment,
            BrowserTabRuntimeAssignment
        ) -> Bool
    let openURL:
        (
            BrowserTabRuntimeAssignment,
            URL,
            BrowserCommandPaletteMode
        ) -> Bool
    let dismiss: () -> Void
    let morphNamespace: Namespace.ID
    let overlayContentInsets: EdgeInsets

    var body: some View {
        if let mode, let sourceAssignment,
            isSourceAvailable(sourceAssignment)
        {
            BrowserCommandPalette(
                browser: browser,
                space: space,
                selectedTabID: selectedTabID,
                initialQuery: mode.initialQuery,
                commands: commands,
                isSourceAvailable: isSourceAvailable,
                selectTab: selectTab,
                openURL: { source, url in openURL(source, url, mode) },
                dismiss: dismiss,
                morphNamespace: morphNamespace,
                overlayContentInsets: overlayContentInsets
            )
            .id(
                BrowserCommandPalettePresentationIdentity(
                    mode: mode,
                    space: space,
                    source: sourceAssignment
                )
            )
            .transition(.browserCommandPaletteOverlay)
            .zIndex(MobileBrowserRootLayout.paletteLayer)
        }
    }

    private var sourceAssignment: BrowserTabRuntimeAssignment? {
        guard let space, let selectedTabID else { return nil }
        return BrowserTabRuntimeAssignment(tabID: selectedTabID, spaceID: space.id, profileID: space.profileID)
    }
}
