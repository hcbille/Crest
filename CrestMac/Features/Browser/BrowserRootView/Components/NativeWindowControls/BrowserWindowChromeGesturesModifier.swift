import AppKit
import SwiftUI

/// An empty stretch of Crest's window chrome behaves like the title bar AppKit
/// draws: dragging it moves the window, and double-clicking it performs the
/// person's title-bar action. Pages keep their own mouse-downs
/// (`BrowserWebHostView`), so none of this reaches web content.
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
