import Foundation

/// What a tab's icon is drawn from: the tab, what it shows, how it chose its
/// icon and the image it wears. Two subjects are equal when they would draw
/// the same icon; the image is compared by its fingerprint, never its bytes.
struct BrowserTabFaviconSubject: Equatable {
    // MARK: - Variables

    let tabID: UUID
    let pageURL: URL?
    let iconMode: TabIconMode
    let symbol: String
    let nativeContent: BrowserNativeTabContent?
    let isStartPage: Bool
    /// The image the tab shows as its icon: the one it wears while its icon
    /// mode shows a favicon, and none otherwise.
    let image: FaviconAssets.Image?

    var emoji: String? {
        BrowserIconSymbol.emoji(from: symbol)
    }

    // MARK: - Initializers

    /// A tab of the read model wearing `image`, the one `FaviconAssets` holds
    /// for it.
    @MainActor
    init(tab: TabStateModel, image: FaviconAssets.Image?) {
        tabID = tab.id
        pageURL = tab.address
        iconMode = tab.iconMode
        symbol = tab.symbol
        nativeContent = tab.nativeTabContent
        isStartPage = tab.isStartPage
        self.image = tab.iconMode.showsFavicon ? image : nil
    }

    /// A tab the core published outside the read model's tab lists, such as
    /// an archived one, wearing `image`.
    init(tab: TabState, image: FaviconAssets.Image?) {
        tabID = tab.id
        pageURL = tab.url.flatMap(URL.init(string:))
        iconMode = tab.iconMode
        symbol = tab.symbol
        nativeContent = tab.nativeContent.map { BrowserNativeTabContent(kind: $0.kind, resourceID: $0.resourceID) }
        isStartPage = tab.surface == .startPage
        self.image = tab.iconMode.showsFavicon ? image : nil
    }
}
