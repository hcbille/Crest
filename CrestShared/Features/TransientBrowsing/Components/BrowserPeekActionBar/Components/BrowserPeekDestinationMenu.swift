import SwiftUI

struct BrowserPeekDestinationMenu: View {
    let spaces: [BrowserSpaceIdentity]
    let selectedSpace: BrowserSpaceIdentity?
    let openInSpace: (BrowserSpaceRuntimeAssignment) -> Void

    var body: some View {
        Menu {
            ForEach(spaces) { candidate in
                Button {
                    openInSpace(candidate.assignment)
                } label: {
                    BrowserSpaceIdentityLabel(
                        identity: candidate,
                        title: BrowserPeekChromePolicy.menuTitle(
                            spaceName: candidate.name
                        )
                    )
                }
            }
            .crestMenuActionLabelStyle()
        } label: {
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .frame(
                    width: BrowserPeekChromePolicy.destinationControlWidth,
                    height: BrowserPeekChromePolicy.controlHeight
                )
                .contentShape(.rect)
        }
        .crestMenuActionLabelStyle()
        .menuIndicator(.hidden)
        .accessibilityLabel("Choose Destination Space")
        .accessibilityValue(Text(selectedSpace?.name ?? "Space"))
        .accessibilityIdentifier("peek-space-picker")
        .help("Open in another Space")
    }
}

#if DEBUG
    #Preview("Component") {
        let spaces = SpaceModel.previewSpaces.map(\.identity)
        BrowserPeekDestinationMenu(spaces: spaces, selectedSpace: spaces[0], openInSpace: { _ in }).padding()
    }
#endif
