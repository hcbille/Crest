import Foundation

/// The engine build an adapter wraps. The raw values are the descriptor's
/// `implementationId` and the token namespace staged navigations carry.
enum BrowserEngineImplementation: String, Codable, Sendable {
    case webKitMacOS = "crest.webkit.macos"
    case webKitIOS = "crest.webkit.ios"
    case chromiumMacOS = "crest.chromium.macos"

    // MARK: - Types

    /// The engine an identity, download or saved page state belongs to. Raw
    /// values are the engine tags persisted interaction state carries.
    enum Family: String, Codable, Hashable, Sendable {
        case webKit = "webkit"
        case chromium
    }

    // MARK: - Variables

    var family: Family {
        switch self {
        case .webKitMacOS, .webKitIOS: .webKit
        case .chromiumMacOS: .chromium
        }
    }
}
