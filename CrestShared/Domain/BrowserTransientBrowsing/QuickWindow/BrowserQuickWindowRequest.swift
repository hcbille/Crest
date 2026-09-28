import Foundation

struct BrowserQuickWindowRequest: Hashable, Identifiable, Sendable {
    private static let emptyLookupURL: URL = {
        var components = URLComponents()
        components.scheme = "crest"
        components.host = "quick-window"
        return components.url ?? URL(fileURLWithPath: "/")
    }()

    let id: UUID
    var url: URL
    let spaceAssignment: BrowserSpaceRuntimeAssignment
    let targetWindowID: UUID?
    let sourcePresentation: BrowserPeekSourcePresentation?
    /// The page the core already opened for the window, a popup window a
    /// page asked for, which its target window hosts until the Quick Window
    /// takes it. A window a relaunch restores has none and loads `url`.
    let openedPageID: UUID?

    var spaceID: UUID { spaceAssignment.spaceID }

    var assignment: BrowserSpaceRuntimeAssignment {
        spaceAssignment
    }

    init(
        id: UUID = UUID(),
        url: URL,
        spaceAssignment: BrowserSpaceRuntimeAssignment,
        targetWindowID: UUID? = nil,
        sourcePresentation: BrowserPeekSourcePresentation? = nil,
        openedPageID: UUID? = nil
    ) {
        self.id = id
        self.url = url
        self.spaceAssignment = spaceAssignment
        self.targetWindowID = targetWindowID
        self.sourcePresentation = sourcePresentation
        self.openedPageID = openedPageID
    }

    static func empty(
        id: UUID = UUID(),
        spaceAssignment: BrowserSpaceRuntimeAssignment,
        targetWindowID: UUID? = nil
    ) -> BrowserQuickWindowRequest {
        BrowserQuickWindowRequest(
            id: id,
            url: emptyLookupURL,
            spaceAssignment: spaceAssignment,
            targetWindowID: targetWindowID
        )
    }

    var initialURL: URL? {
        url == Self.emptyLookupURL ? nil : url
    }

    /// Two requests for the same address in the same Space ask for the same
    /// window, except a popup window's: every window a page asks for is one
    /// of its own.
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.openedPageID == nil, rhs.openedPageID == nil else { return lhs.id == rhs.id }
        return switch (lhs.initialURL, rhs.initialURL) {
        case (.some(let lhsURL), .some(let rhsURL)):
            lhs.assignment == rhs.assignment && lhsURL == rhsURL
        case (.none, .none):
            lhs.id == rhs.id
        default:
            false
        }
    }

    func hash(into hasher: inout Hasher) {
        if openedPageID == nil, let initialURL {
            hasher.combine(assignment)
            hasher.combine(initialURL)
        } else {
            hasher.combine(id)
        }
    }
}

// MARK: - Codable

/// SwiftUI saves a Quick Window's request for scene restoration, so the window
/// it targets keeps the stored identity spelling a build before S6.2 restores.
extension BrowserQuickWindowRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case spaceAssignment
        case targetWindowID
        case sourcePresentation
        case openedPageID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            url: try container.decode(URL.self, forKey: .url),
            spaceAssignment: try container.decode(BrowserSpaceRuntimeAssignment.self, forKey: .spaceAssignment),
            targetWindowID: try container.decodeIdentityIfPresent(forKey: .targetWindowID),
            sourcePresentation: try container.decodeIfPresent(
                BrowserPeekSourcePresentation.self, forKey: .sourcePresentation),
            openedPageID: try container.decodeIfPresent(UUID.self, forKey: .openedPageID))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(spaceAssignment, forKey: .spaceAssignment)
        try container.encodeStoredIdentityIfPresent(targetWindowID, forKey: .targetWindowID)
        try container.encodeIfPresent(sourcePresentation, forKey: .sourcePresentation)
        try container.encodeIfPresent(openedPageID, forKey: .openedPageID)
    }
}
