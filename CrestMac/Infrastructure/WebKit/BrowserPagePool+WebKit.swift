import Foundation
import WebKit

/// The pool's WebKit hosting that only a Mac window does: popups WebKit
/// creates itself and the hosted web notifications their bridges post. What
/// every page owner does with WebKit lives in `BrowserPageOwner`.
extension BrowserPagePool {
    // MARK: - Actions - Pages

    /// Adopts the web view WebKit pre-made for a popup as a new tab in the
    /// opener's Space, selected unless `selecting` is false.
    ///
    /// Per-Space isolation needs no work here: WebKit derives the popup's
    /// configuration from the opener's, so it already carries the opener's
    /// `websiteDataStore` and web extension controller. The Space lookup only
    /// confirms the tab landed in the opener's own profile.
    func adoptPopupWebView(
        configuration: WKWebViewConfiguration,
        requestedURL: URL?,
        opener: BrowserPage,
        selecting: Bool = true
    ) -> WKWebView? {
        // A popup keeps the opener's configuration, which carries its website
        // data store, content controller and web extension controller.
        adoptPopupPage(requestedURL: requestedURL, opener: opener, selecting: selecting) { space in
            .popup(configuration, contentRuleLists: contentRuleLists(for: space))
        }?.webKitView
    }

    // MARK: - Actions - Script message routing

    func routeHostedWebNotificationMessage(_ message: WKScriptMessage) {
        residentPage(sending: message)?.receiveHostedWebNotificationMessage(message)
    }
}
