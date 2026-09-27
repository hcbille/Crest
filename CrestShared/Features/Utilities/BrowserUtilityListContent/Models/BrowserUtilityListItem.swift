import SwiftUI

enum BrowserUtilityListItem: Identifiable, Sendable {
    case archive(ArchivedTabState)
    case history(HistoryEntryState)
    case download(DownloadState)

    var id: BrowserUtilityListItemID {
        switch self {
        case .archive(let item): .archive(item.tab.id)
        case .history(let item): .history(item.id)
        case .download(let item): .download(item.id)
        }
    }

    var date: Date {
        switch self {
        case .archive(let item): item.archivedAt
        case .history(let item): item.lastVisitedAt
        case .download(let item): item.createdAt
        }
    }
}

enum BrowserUtilityListItemID: Hashable, Sendable {
    case archive(UUID)
    case history(UUID)
    case download(UUID)
}

struct BrowserUtilityListSection: Identifiable, Sendable {
    let timeframe: BrowserUtilityTimeSection
    let items: [BrowserUtilityListItem]

    var id: String { timeframe.id }
}

extension EnvironmentValues {
    /// The images the tabs a utility list shows wear, which the list's host
    /// reads from the core's read model.
    @Entry var browserFavicons: FaviconAssets? = nil
}
