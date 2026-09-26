import SwiftUI

struct BrowserPrivacySpaceSection: View {
    @Binding var selectedSpaceID: SpaceID?
    let spaces: [SpaceModel]

    var body: some View {
        Section("Space", systemImage: "square.grid.2x2") {
            CrestSpaceMenuPicker(
                "Permissions for",
                selection: $selectedSpaceID,
                spaces: CrestSpaceIdentity.list(spaces)
            )
        }
    }
}

#if DEBUG
    #Preview("Space selection") {
        @Previewable @State var browser = BrowserStore(session: .preview)
        @Previewable @State var selection: SpaceID? = BrowserSession.preview.spaces[0].id
        Form { BrowserPrivacySpaceSection(selectedSpaceID: $selection, spaces: browser.spaceModels) }
            .crestSettingsForm().frame(width: 420, height: 220)
    }
#endif
