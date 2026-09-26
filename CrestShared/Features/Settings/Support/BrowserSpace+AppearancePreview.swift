import Foundation

extension BrowserSpace {
    // MARK: - Initializers

    /// A detached value of how a Space of the read model looks, for the
    /// appearance previews that draw a sample sidebar in its look: its identity,
    /// look, lock and folders, with no tabs or history. TRANSITIONAL until
    /// S6.6e gives the previews a detached read model.
    @MainActor
    init(appearanceOf space: SpaceModel) {
        let settings = space.settings
        self.init(
            id: space.id, profile: BrowsingProfile(id: space.profileID), name: settings.name,
            symbol: settings.symbol, accent: settings.accent, branding: BrowserSpaceBranding(look: settings.look),
            folders: space.folders.models.map { BrowserFolder(core: $0.value) }, tabs: [],
            accessPolicy: BrowserSpaceAccessPolicy(coreTerm: settings.accessPolicy) ?? .deviceOwnerAuthentication)
    }
}
