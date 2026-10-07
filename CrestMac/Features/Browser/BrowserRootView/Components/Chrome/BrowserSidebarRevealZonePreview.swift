import SwiftUI

/// The sidebar's hover area, drawn in the accent Settings tints its controls
/// with while someone adjusts its width and fading out about three seconds after the last change.
///
/// It never takes input: the strip it outlines is the real one, and the page
/// underneath keeps answering the pointer.
struct BrowserSidebarRevealZonePreview: View {
    var edge: HorizontalEdge = .leading

    @AppStorage(SidebarRevealWidthPreference.key)
    private var storedWidth = SidebarRevealWidthPreference.defaultValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity = 0.0
    @State private var fade: Task<Void, Never>?

    private let preview = SidebarRevealWidthPreview.shared

    var body: some View {
        CrestBrandTheme.accent
            .frame(width: SidebarRevealWidthPreference.width(storedWidth))
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity, alignment: edge == .leading ? .leading : .trailing)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: preview.adjustmentCount) { restartFade() }
            .onDisappear { fade?.cancel() }
    }

    /// Full strength straight away, then gone three seconds after the last
    /// adjustment. Reduce Motion holds it and removes it without the fade.
    private func restartFade() {
        fade?.cancel()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { opacity = 1 }
        fade = Task {
            if reduceMotion {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                opacity = 0
            } else {
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 2.5)) { opacity = 0 }
            }
        }
    }
}
