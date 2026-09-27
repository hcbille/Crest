import AppKit

enum BrowserNativeWindowControlsPolicy {
    static let toolbarIdentifier = NSToolbar.Identifier(
        "crest.browser.window-chrome"
    )
    static let buttonTypes: [NSWindow.ButtonType] = [
        .closeButton,
        .miniaturizeButton,
        .zoomButton,
    ]

    static func sidebarOffset(
        onRight: Bool, windowWidth: CGFloat, sidebarWidth: CGFloat,
        in styleMask: NSWindow.StyleMask
    ) -> CGFloat {
        guard onRight, !styleMask.contains(.fullScreen) else { return 0 }
        return max(0, windowWidth - sidebarWidth)
    }

    /// The style a window returns to when Crest's chrome leaves it. AppKit
    /// owns the fullscreen bit and changes it only in its own transitions, so
    /// a window left while in fullscreen, or first met there, keeps the state
    /// AppKit gave it.
    static func restoredStyleMask(
        original: NSWindow.StyleMask, current: NSWindow.StyleMask
    ) -> NSWindow.StyleMask {
        original.subtracting(.fullScreen).union(current.intersection(.fullScreen))
    }

    static func showsToolbar(in styleMask: NSWindow.StyleMask) -> Bool {
        !styleMask.contains(.fullScreen)
    }

    /// A collapsed sidebar owns no place for window controls in ordinary
    /// windowed chrome. Native fullscreen supplies its own top bar, so those
    /// standard controls remain available there regardless of sidebar state.
    static func showsWindowControls(
        sidebarPresentationShowsControls: Bool,
        in styleMask: NSWindow.StyleMask
    ) -> Bool {
        sidebarPresentationShowsControls || styleMask.contains(.fullScreen)
    }
}
