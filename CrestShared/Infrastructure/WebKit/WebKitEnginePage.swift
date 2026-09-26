import WebKit

/// A page WebKit's binding built for a page the core opened: its web view,
/// built for the page's profile with the platform's own settings, and WebKit's
/// page port over it. The page's owner hosts the web view and answers its
/// delegates until the binding does (WP C (j1)).
@MainActor
final class WebKitEnginePage {
    // MARK: - Variables

    /// The core's page this one is.
    let id: UUID
    let webView: WKWebView
    let engine: BrowserWebKitPageEngine
    /// The content rules the page was built with.
    let contentRuleLists: [WKContentRuleList]
    /// False when the page shares the user content controller of the page its
    /// configuration came from, which every popup does: WebKit copies the
    /// opener's configuration and the copy keeps the same controller.
    /// Installing the same script message handler twice on it throws, and
    /// removing one would strip it from the opener.
    let ownsUserContentController: Bool

    // MARK: - Initializers

    init(id: UUID, webView: WKWebView, contentRuleLists: [WKContentRuleList], ownsUserContentController: Bool) {
        self.id = id
        self.webView = webView
        engine = BrowserWebKitPageEngine(webView: webView)
        self.contentRuleLists = contentRuleLists
        self.ownsUserContentController = ownsUserContentController
    }
}
