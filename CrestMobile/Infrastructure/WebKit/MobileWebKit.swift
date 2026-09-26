import UIKit
import WebKit

/// What only iPhone and iPad WebKit pages need, which WebKit's binding applies
/// as it builds a page: the presentation WebKit recommends, inline media that
/// waits for the person, and the web view.
@MainActor
enum MobileWebKit {
    // MARK: - Static Variables

    static let preferredContentMode = WKWebpagePreferences.ContentMode.recommended

    // MARK: - Actions - Pages

    /// Adds the mobile media policy to a new page's configuration, on top of
    /// the settings both platforms share: the inactive scheduling policy above
    /// all, which lets WebKit suspend a resident background tab on the
    /// platform that jetsams.
    static func decorate(_ configuration: WKWebViewConfiguration) {
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.addUserScript(MobileMediaPlaybackPolicy.inlineVideoScript)
    }

    /// The web view over `configuration`, one the binding assembled or one
    /// WebKit made for a popup.
    static func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .clear
        return webView
    }
}
