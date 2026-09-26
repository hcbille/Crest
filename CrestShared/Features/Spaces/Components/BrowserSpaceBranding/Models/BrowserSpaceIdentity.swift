import Foundation

/// What a Space's identity views draw: its name, symbol and look, and whether
/// it asks for authentication. Read once from the Space, so a view draws the
/// same crest whichever vocabulary its caller holds the Space in.
struct BrowserSpaceIdentity: Equatable, Identifiable {
    // MARK: - Variables

    let id: SpaceID
    let profileID: UUID
    let name: String
    let symbol: String
    let branding: BrowserSpaceBranding
    let accessPolicy: BrowserSpaceAccessPolicy

    /// Where the Space lives: its identity and profile.
    var assignment: BrowserSpaceRuntimeAssignment {
        BrowserSpaceRuntimeAssignment(spaceID: id, profileID: profileID)
    }

    // MARK: - Initializers

    /// A Space of the core's read model.
    @MainActor
    init(space: SpaceModel) {
        id = space.id
        profileID = space.profileID
        name = space.settings.name
        symbol = space.settings.symbol
        branding = BrowserSpaceBranding(look: space.settings.look)
        accessPolicy = BrowserSpaceAccessPolicy(coreTerm: space.settings.accessPolicy) ?? .deviceOwnerAuthentication
    }

    /// A Space of the session copy. TRANSITIONAL until the Space pass draws
    /// every identity from the read model.
    init(space: BrowserSpace) {
        id = space.id
        profileID = space.profile.id
        name = space.name
        symbol = space.symbol
        branding = space.branding
        accessPolicy = space.accessPolicy
    }
}
