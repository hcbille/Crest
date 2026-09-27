import SwiftUI

struct BrowserImportSpaceCustomizationContent: View {
    let previewSpace: SpaceModel?
    let previewFavicons: FaviconAssets
    @Binding var name: String
    @Binding var symbol: String
    @Binding var branding: SpaceBranding
    let done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BrowserImportSpaceCustomizationHeader(done: done)
            BrowserImportSpaceCustomizationEditor(
                previewSpace: previewSpace,
                previewFavicons: previewFavicons,
                name: $name,
                symbol: $symbol,
                branding: $branding
            )
        }
    }
}
