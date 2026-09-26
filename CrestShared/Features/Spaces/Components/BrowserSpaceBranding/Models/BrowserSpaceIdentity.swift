import Foundation

/// What a Space's identity views draw: its name, symbol and look, and whether
/// it asks for authentication. Read once from the Space, so a view draws the
/// same crest whichever form its caller holds the Space in.
struct BrowserSpaceIdentity: Equatable, Identifiable {
    // MARK: - Variables

    let id: SpaceID
    let profileID: UUID
    let name: String
    let symbol: String
    let accent: SpaceAccent
    let branding: BrowserSpaceBranding
    /// The Space shows only while this process holds the grant for its
    /// profile, as the core decides from its access policy.
    let requiresAuthentication: Bool

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
        accent = space.settings.accent
        branding = BrowserSpaceBranding(look: space.settings.look)
        requiresAuthentication = space.settings.requiresAuthentication
    }

    /// A Space value no session holds yet: a setup draft, an import under
    /// review, or a preview.
    init(space: BrowserSpace) {
        id = space.id
        profileID = space.profile.id
        name = space.name
        symbol = space.symbol
        accent = space.accent
        branding = space.branding
        requiresAuthentication = space.accessPolicy.requiresAuthentication
    }
}

/// A Space as a picker or identity view draws it, whatever form the caller
/// holds it in: the read model's Space, or a value no session holds yet.
@MainActor
protocol BrowserSpaceIdentifying: Identifiable where ID == SpaceID {
    var identity: BrowserSpaceIdentity { get }
}

extension BrowserSpaceIdentity: BrowserSpaceIdentifying {
    var identity: BrowserSpaceIdentity { self }
}

extension SpaceModel: BrowserSpaceIdentifying {
    var identity: BrowserSpaceIdentity { BrowserSpaceIdentity(space: self) }
}

extension BrowserSpace: BrowserSpaceIdentifying {
    var identity: BrowserSpaceIdentity { BrowserSpaceIdentity(space: self) }
}
