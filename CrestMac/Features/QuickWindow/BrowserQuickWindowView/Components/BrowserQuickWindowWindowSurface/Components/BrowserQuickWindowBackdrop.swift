import SwiftUI

struct BrowserQuickWindowBackdrop: View {
    let space: SpaceModel?
    let opacity: Double
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            BrowserWindowAtmosphere(space: space)
                .opacity(opacity)
        }
        // The window's background, wherever no page or control covers it, is
        // chrome, the toolbar strip under the title bar included.
        .overlay { BrowserWindowTitleBarSurface() }
        .ignoresSafeArea()
        .animation(
            BrowserVisualAccessibilityPolicy.animation(
                CrestMotion.windowBackdrop,
                reduceMotion: reduceMotion
            ),
            value: opacity
        )
    }
}

#if DEBUG
    #Preview("Component") {
        BrowserQuickWindowBackdrop(
            space: BrowserCommandPalettePreviewFixture.space, opacity: 0.8, reduceMotion: true
        ).frame(width: 540, height: 360)
    }
#endif
