import SwiftUI

extension View {
    /// Makes this empty stretch of window chrome move the window when dragged
    /// and perform the person's title-bar action when double-clicked.
    func browserWindowChromeGestures() -> some View {
        modifier(BrowserWindowChromeGesturesModifier())
    }
}
