import Foundation

extension CrestCore {
    /// The tab a Space shows when no window chose one, by the core's rule: the
    /// first open tab, else the first pinned one, else the first tab. For a
    /// Space no window shows, such as a draft, a preview or an import under
    /// review.
    @MainActor
    func fallbackTabID(in space: SpaceModel) -> TabID? {
        let tabs = space.tabs.models
        guard let index = (try? query(FallbackTab(placements: tabs.map(\.placement))))?.index,
            tabs.indices.contains(index)
        else { return nil }
        return tabs[index].id
    }

    /// TRANSITIONAL until the page pool's tests move to the read model with
    /// WP C j2: the same tab for a Space of the session copy.
    func fallbackTabID(in space: BrowserSpace) -> TabID? {
        guard let index = (try? query(FallbackTab(placements: space.tabs.map(\.placement))))?.index,
            space.tabs.indices.contains(index)
        else { return nil }
        return space.tabs[index].id
    }
}
