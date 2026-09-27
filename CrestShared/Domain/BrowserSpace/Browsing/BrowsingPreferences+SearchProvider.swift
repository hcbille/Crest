import Foundation

/// The engine a Space searches with, read from and written to the selection
/// the core keeps: a built-in, or one of the Space's own engines by identity.
extension BrowsingPreferences {
    // MARK: - Variables

    /// Every engine the Space can search with: the built-ins, then its own.
    var availableSearchProviders: [SearchProvider] {
        SearchProvider.all + customSearchProviders.map(SearchProvider.init(custom:))
    }

    /// The engine the Space searches with. A selection that names no engine
    /// the Space holds reads as Google, and choosing one it does not hold
    /// selects Google.
    var searchProvider: SearchProvider {
        get {
            searchProvider(builtIn: selectedBuiltInEngine, customID: selectedCustomEngineID) ?? .google
        }
        set {
            let selection = (availableSearchProviders.contains(newValue) ? newValue : .google).selection
            selectedBuiltInEngine = selection.builtIn
            selectedCustomEngineID = selection.customEngineID
        }
    }

    // MARK: - Actions - Lookup

    /// The engine `builtIn` or `customID` names among this Space's engines.
    func searchProvider(builtIn: BuiltInSearchEngine?, customID: UUID?) -> SearchProvider? {
        if let builtIn { return SearchProvider.named(builtIn.name) }
        guard let customID, let custom = customSearchProviders.first(where: { $0.id == customID }) else { return nil }
        return SearchProvider(custom: custom)
    }
}
