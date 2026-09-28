import AppKit
import SwiftUI

/// An empty stretch of Crest's window chrome behaves like the title bar AppKit
/// draws: dragging it moves the window, and double-clicking it performs the
/// person's title-bar action. The window itself is not movable while Crest's
/// chrome styles it (`BrowserNativeWindowControlsHostView`), so presses on
/// chrome are the only ones that move it, and none of them reaches web
/// content. This is for chrome that keeps SwiftUI gestures of its own, such as
/// the sidebar's empty background and its context menu; plain chrome uses
/// `BrowserWindowTitleBarSurface`, which decides each press as AppKit does.
struct BrowserWindowChromeGesturesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .gesture(WindowDragGesture())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    guard let window = NSApp.currentEvent?.window ?? NSApp.keyWindow else { return }
                    BrowserWindowTitleBarAction.current().perform(on: window)
                }
            )
            .allowsWindowActivationEvents()
    }
}
