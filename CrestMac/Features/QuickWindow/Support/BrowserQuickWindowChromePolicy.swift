import Foundation

enum BrowserQuickWindowChromePolicy {
    static let showsSourceSpaceBeforeAddress = true
    static let showsSingleMenuIndicator = true

    static func destinationTitle(spaceName: String) -> String {
        String(localized: "Open in \(spaceName)")
    }
}
