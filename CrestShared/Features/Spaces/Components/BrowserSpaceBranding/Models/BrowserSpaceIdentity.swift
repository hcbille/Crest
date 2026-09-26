import Foundation

/// What a Space's identity views draw: its name, symbol and look, and whether
/// it asks for authentication. Read once from the Space, so a view draws the
/// same crest whichever form its caller holds the Space in.
struct BrowserSpaceIdentity: Equatable, Identifiable {
    // MARK: - Variables

    let id: SpaceID
    let profileID: UUID
    private(set) var name: String
    private(set) var symbol: String
    let accent: SpaceAccent
    private(set) var branding: BrowserSpaceBranding
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

    /// A Space of a manual setup, before the setup makes it: the name it
    /// shows and the look it takes, asking for no authentication.
    init(draft space: SetupDraftSpace) {
        id = space.spaceID
        profileID = space.profileID
        name = space.shownName
        symbol = space.customization.symbol
        accent = space.customization.accent
        branding = BrowserSpaceBranding(look: space.customization.branding)
        requiresAuthentication = false
    }

    /// TRANSITIONAL until the Chromium extension store reads the read model
    /// (WP C l/i): a Space of the session copy.
    init(space: BrowserSpace) {
        id = space.id
        profileID = space.profile.id
        name = space.name
        symbol = space.symbol
        accent = space.accent
        branding = space.branding
        requiresAuthentication = space.accessPolicy.requiresAuthentication
    }

    // MARK: - Actions - Drafting

    /// This identity as a draft shows it before it is saved: named `name` and
    /// wearing `branding` and `symbol`.
    func wearing(_ branding: BrowserSpaceBranding, symbol: String, name: String) -> BrowserSpaceIdentity {
        var draft = self
        draft.branding = branding
        draft.symbol = symbol
        draft.name = name
        return draft
    }
}

/// A Space as a picker or identity view draws it, whatever form the caller
/// holds it in: the read model's Space, or the identity of one no session
/// holds yet, such as a setup draft.
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

/// TRANSITIONAL until the Chromium extension store reads the read model
/// (WP C l/i).
extension BrowserSpace: BrowserSpaceIdentifying {
    var identity: BrowserSpaceIdentity { BrowserSpaceIdentity(space: self) }
}
