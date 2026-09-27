import SwiftUI

/// The outline a row wears while releasing would file the lifted item inside
/// it: an open tab a lifted tab would make a folder with, or a collapsed
/// folder a lifted folder would move into.
///
/// Whether that is what release means is resolved by
/// `BrowserSidebarReorderState` from the measured geometry, so this view reads
/// the answer rather than re-deriving it from a drag session. It reads it
/// itself, so only the outline redraws as a lift's target moves, never the
/// row it decorates.
struct BrowserFolderNestDropHighlight: View {
    /// What the outline marks.
    enum Target: Equatable {
        case currentTab(UUID)
        case folder(UUID)
    }

    let state: BrowserSidebarReorderState
    let target: Target

    var body: some View {
        if isTargeted {
            RoundedRectangle(
                cornerRadius: BrowserDeviceAppearanceStore.shared.containerCornerRadius(),
                style: .continuous
            )
            .fill(CrestColor.dropIndicator.opacity(0.14))
            .overlay {
                RoundedRectangle(
                    cornerRadius: BrowserDeviceAppearanceStore.shared.containerCornerRadius(),
                    style: .continuous
                )
                .strokeBorder(CrestColor.dropIndicator, lineWidth: 1.5)
            }
            .padding(.horizontal, CrestSpacing.small)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var isTargeted: Bool {
        switch target {
        case .currentTab(let tabID):
            state.resolvedTarget?.kind == .createCurrentFolder(tabID)
        case .folder(let folderID):
            state.isTargetedFolder(folderID)
                && BrowserFolderRowPresentationPolicy.showsNestOutline(for: state.lift?.item)
        }
    }
}
