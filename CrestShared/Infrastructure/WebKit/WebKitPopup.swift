import WebKit

/// A popup WebKit makes for a page's document: the configuration WebKit
/// derived from its opener's, which the popup's page must use exactly as
/// given, since it carries the opener's website data store and shares its
/// user content controller.
struct WebKitPopup {
    // MARK: - Variables

    let configuration: WKWebViewConfiguration
}
