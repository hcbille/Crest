import Foundation

enum BrowserSoftwareUpdateChannel: String, Identifiable, Sendable, CaseIterable {
    case stable
    case nightly
    case development
    case experimental

    /// Experimental is offered only by a build packaged for it, so once the
    /// branch it serves reaches Development, normal builds do not show an
    /// obsolete choice.
    static var allCases: [Self] {
        var channels: [Self] = [.stable, .nightly, .development]

        let bundledDefault =
            Bundle.main.object(
                forInfoDictionaryKey: "CrestDefaultUpdateChannel"
            ) as? String

        if bundledDefault == Self.experimental.rawValue {
            channels.append(.experimental)
        }

        return channels
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .stable: "Stable"
        case .nightly: "Nightly"
        case .development: "Development"
        case .experimental: "Experimental"
        }
    }

    var guidance: String {
        switch self {
        case .stable:
            "Recommended releases intended for everyday use."
        case .nightly:
            "Daily snapshots of current development. Nightly builds may be less reliable."
        case .development:
            "The latest signed build from public main. Development builds can change several times a day."
        case .experimental:
            "Experimental branch builds for testing work before it reaches Development."
        }
    }

    var allowedSparkleChannels: Set<String> {
        switch self {
        case .stable: []
        case .nightly: ["nightly"]
        case .development: ["development"]
        case .experimental: ["experimental"]
        }
    }

    var customFeedURL: URL? {
        feedURL(for: BrowserEngineRegistration.current.implementationId.family)
    }

    /// Feeds follow the installed product composition. A WebKit preference
    /// inside the Chromium product keeps updating that same dual-engine app.
    func feedURL(for engine: BrowserEngineImplementation.Family) -> URL? {
        let suffix = engine == .webKit ? "-webkit" : ""
        let filename: String
        switch self {
        case .stable, .nightly:
            guard engine == .webKit else { return nil }
            filename = "appcast-webkit.xml"
        case .development: filename = "appcast-development\(suffix).xml"
        case .experimental: filename = "appcast-experimental\(suffix).xml"
        }
        return URL(string: "https://raw.githubusercontent.com/pauljoda/Crest/updates/\(filename)")
    }
}
