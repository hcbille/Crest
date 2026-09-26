import Foundation

enum BrowserQuickWindowChromePolicy {
    static func destinationTitle(spaceName: String) -> String {
        String(localized: "Open in \(spaceName)")
    }
}
