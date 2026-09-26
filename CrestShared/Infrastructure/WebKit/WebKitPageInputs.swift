import WebKit

/// What a page's owner hands WebKit's binding for a page it asks the core to
/// open, which the binding builds the page from if WebKit hosts it.
/// TRANSITIONAL until the binding keeps each profile's website data and each
/// Space's content rules itself (WP C (j2)).
struct WebKitPageInputs {
    // MARK: - Variables

    /// The website data store the page keeps its data in, or nil for its
    /// profile's own store as the launch scopes it.
    let websiteDataStore: WKWebsiteDataStore?
    /// The content rules the page's Space applies.
    let contentRuleLists: [WKContentRuleList]
    /// A configuration the page uses exactly as given: the one WebKit made for
    /// a popup from its opener's, or one a test assembled.
    let configuration: WKWebViewConfiguration?
    /// Whether the page shares the user content controller of the page
    /// `configuration` came from, as a popup shares its opener's.
    let sharesUserContentController: Bool

    // MARK: - Initializers

    init(
        websiteDataStore: WKWebsiteDataStore? = nil,
        contentRuleLists: [WKContentRuleList] = [],
        configuration: WKWebViewConfiguration? = nil,
        sharesUserContentController: Bool = false
    ) {
        self.websiteDataStore = websiteDataStore
        self.contentRuleLists = contentRuleLists
        self.configuration = configuration
        self.sharesUserContentController = sharesUserContentController
    }

    /// A popup's page, built from the configuration WebKit derived from its
    /// opener's, which shares the opener's user content controller.
    static func popup(_ configuration: WKWebViewConfiguration, contentRuleLists: [WKContentRuleList]) -> WebKitPageInputs {
        WebKitPageInputs(
            contentRuleLists: contentRuleLists, configuration: configuration, sharesUserContentController: true)
    }
}
