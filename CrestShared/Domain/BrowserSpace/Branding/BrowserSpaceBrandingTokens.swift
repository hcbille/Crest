import Foundation

enum BrowserSpaceForegroundTone: Equatable, Sendable {
    case light
    case dark
}

/// The part a Space color plays, by its place in the Space's palette.
enum BrowserSpaceBrandColorRole: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case background
    case primary
    case secondary

    var id: Int { rawValue }
}

extension SpaceTextColorMode {
    /// The tone a Space's text keeps whatever its colors; automatic works it
    /// out from them.
    var foregroundTone: BrowserSpaceForegroundTone? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
