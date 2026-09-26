import Foundation

/// Crest's address namespace is separate from Chromium's privileged origins.
/// Translate only at the engine boundary, leaving web and extension URLs intact.
enum ChromiumInternalURL {
    static func engine(_ value: String) -> String {
        replacingScheme(in: value, from: "crest", to: "chrome")
    }

    static func presented(_ value: String) -> String {
        replacingScheme(in: value, from: "chrome", to: "crest")
    }

    private static func replacingScheme(in value: String, from: String, to: String) -> String {
        let prefix = from + "://"
        guard value.prefix(prefix.count).lowercased() == prefix else { return value }
        // Preserve escaped paths, query strings and fragments byte for byte.
        return to + "://" + value.dropFirst(prefix.count)
    }
}
