import AppKit

/// What a shell window's content does with a mouse's Back or Forward button:
/// the content knows its pages and where its sidebar is.
/// `BrowserMacMouseButtons` pairs each press it took with its release.
@MainActor
protocol BrowserMacWindowPointerNavigation: AnyObject {
    /// Acts on a press of `action`'s button at `event`, answering whether
    /// Crest took it. One it did not take goes on to the view under the
    /// pointer, with its drags and release.
    func takePress(_ action: BrowserSidebarMouseButtonAction, at event: NSEvent) -> Bool
}
