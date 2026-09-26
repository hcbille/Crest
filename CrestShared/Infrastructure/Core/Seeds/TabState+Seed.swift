import Foundation

extension TabState.Seed {
    // MARK: - Initializers

    /// A tab to seed a Space with, showing `url`, or `nativeContent` in place
    /// of a page, or a Start Page with neither. A saved or pinned tab keeps
    /// the address it was built at unless `savedURL` names another.
    init(
        id: UUID = UUID(),
        title: String,
        url: URL?,
        nativeContent: BrowserNativeTabContent? = nil,
        savedURL: URL? = nil,
        symbol: String = "globe",
        faviconURL: URL? = nil,
        iconAccent: TabIconAccent? = nil,
        iconMode: TabIconMode? = nil,
        placement: TabPlacement,
        folderID: UUID? = nil,
        splitGroupID: UUID? = nil,
        lastActivatedAt: Date = .now,
        positionModifiedAt: Date? = nil,
        customTitle: String? = nil,
        titleModifiedAt: Date? = nil,
        keepsPageLoaded: Bool = false
    ) {
        let address = nativeContent == nil ? url : nil
        self.init(
            id: id, title: title, url: address?.absoluteString,
            nativeContent: nativeContent.map { NativeTabContent(kind: $0.kind, resourceID: $0.resourceID) },
            savedURL: nativeContent == nil ? (savedURL ?? (placement.isDurable ? address : nil))?.absoluteString : nil,
            symbol: symbol, faviconURL: faviconURL?.absoluteString, iconAccent: iconAccent, storedIconMode: iconMode,
            placement: placement, folderID: folderID, splitGroupID: splitGroupID, lastActivatedAt: lastActivatedAt,
            positionModifiedAt: positionModifiedAt, customTitle: customTitle, titleModifiedAt: titleModifiedAt,
            keepsPageLoaded: keepsPageLoaded)
    }

    /// A Start Page tab to seed a Space with.
    static func startPage(id: UUID = UUID(), placement: TabPlacement = .current, lastActivatedAt: Date = .now)
        -> TabState.Seed
    {
        TabState.Seed(
            id: id, title: BrowserTab.startPageTitle, url: nil, symbol: BrowserTab.startPageSymbol,
            placement: placement,
            lastActivatedAt: lastActivatedAt)
    }
}
