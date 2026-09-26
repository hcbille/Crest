import Foundation

struct BrowserSettingsNavigationState: Equatable {
    var selection: BrowserSettingsDestination
    var searchText: String

    init(
        selection: BrowserSettingsDestination = .general,
        searchText: String = ""
    ) {
        self.selection = selection
        self.searchText = searchText
    }

    /// The destinations the sidebar lists: those `state`'s engines provide,
    /// matching the search.
    @MainActor
    func visibleDestinations(locale: Locale, in state: CoreState) -> [BrowserSettingsDestination] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return BrowserSettingsDestination.platformCases(in: state)
        }

        let matches = BrowserSettingsDestination.platformCases(in: state).filter {
            $0.matchesSearchQuery(query, locale: locale)
        }
        guard selection == .passwords, !matches.contains(.passwords) else {
            return matches
        }
        return [.passwords] + matches
    }

    mutating func applyExternalRoute(
        _ destination: BrowserSettingsDestination,
        revision: Int
    ) {
        guard revision > 0 else { return }
        selection = destination
    }
}
