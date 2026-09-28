import AppKit

/// Empty window chrome that stands in for the title bar AppKit draws. The
/// window itself is not movable while Crest's chrome styles it
/// (`BrowserNativeWindowControlsHostView`), so a press here is what moves it.
/// Like AppKit's own title bar, it answers each mouse-down by its click count:
/// a press starts a window drag, and the second press of a double-click
/// performs the person's title-bar action instead.
@MainActor
final class BrowserWindowTitleBarSurfaceView: NSView {
    // MARK: - Actions - Mouse

    /// A press on an inactive window moves it at once, as its title bar does.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        // A window in fullscreen has no title bar to stand in for; its own
        // appears in the menu bar's place and moves it.
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        if event.clickCount == 2 {
            BrowserWindowTitleBarAction.current().perform(on: window)
        } else {
            window.performDrag(with: event)
        }
    }
}
