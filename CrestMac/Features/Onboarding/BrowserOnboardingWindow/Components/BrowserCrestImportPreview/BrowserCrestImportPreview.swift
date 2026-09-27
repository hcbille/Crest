import SwiftUI

struct BrowserCrestImportPreview: View {
    let space: SpaceModel?
    /// The images the Space's tabs would wear.
    let favicons: FaviconAssets
    let sourceName: String
    var isSpaceIncluded = true
    var matchedTabIDs: Set<UUID> = []

    var body: some View {
        if !isSpaceIncluded {
            BrowserImportSidebarFrame(
                branding: .neutral
            ) {
                ContentUnavailableView(
                    "Space Skipped",
                    systemImage: "rectangle.stack.badge.minus",
                    description: Text("Turn on Move Space to include it in this import.")
                )
            }
            .accessibilityLabel("Space skipped")
        } else if let space {
            BrowserImportSidebarFrame(branding: space.settings.look) {
                BrowserCrestImportContent(
                    space: space,
                    favicons: favicons,
                    matchedTabIDs: matchedTabIDs
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Crest \(space.settings.name) sidebar after import")
        } else {
            BrowserImportSidebarFrame(
                branding: .neutral
            ) {
                ContentUnavailableView(
                    "Preview Unavailable",
                    systemImage: "rectangle.stack.badge.minus",
                    description: Text("Crest could not build this \(sourceName) Space preview.")
                )
            }
        }
    }
}
