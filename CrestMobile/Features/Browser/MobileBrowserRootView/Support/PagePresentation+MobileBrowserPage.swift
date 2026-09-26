import Foundation

/// What a touch page surface shows for a tab, from the page its store holds.
extension PagePresentation {
    // MARK: - Actions - Presenting

    /// What a surface shows for a tab whose surface is `surface`, or for no
    /// tab, drawing `page` when the store holds one. A surface that
    /// `restoresUnloaded` brings an unloaded tab's page back by itself.
    @MainActor
    static func of(_ surface: TabSurface?, page: MobileBrowserPage?, restoresUnloaded: Bool = false) -> PagePresentation
    {
        of(
            surface, hasPage: page != nil, hasNavigationFailure: page?.live.failure != nil,
            hasProcessFailure: page?.showsProcessFailure == true, restoresUnloaded: restoresUnloaded)
    }
}
