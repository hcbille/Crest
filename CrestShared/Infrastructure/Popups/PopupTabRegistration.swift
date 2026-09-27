import Foundation

/// The tab a popup was adopted into, together with the Space that owns it, as
/// the read model holds them, so a page owner can build the adopting page
/// while WebKit waits.
@MainActor
struct BrowserPopupTabRegistration {
    let tab: TabStateModel
    let space: SpaceModel
}
