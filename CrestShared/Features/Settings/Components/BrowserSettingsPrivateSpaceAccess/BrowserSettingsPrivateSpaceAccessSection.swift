import SwiftUI

struct BrowserSettingsPrivateSpaceAccessSection: View {
    // MARK: - Variables

    let space: BrowserSpaceIdentity
    let accessController: BrowserSpaceAccessController
    let detail: String

    // MARK: - Initializers

    init(
        space: some BrowserSpaceIdentifying,
        accessController: BrowserSpaceAccessController,
        detail: String = "Unlock this Space to view or change its private settings."
    ) {
        self.space = space.identity
        self.accessController = accessController
        self.detail = detail
    }

    // MARK: - Body

    var body: some View {
        Section("Private Space", systemImage: "lock.shield") {
            Text(detail)
                .crestFormFootnote()

            BrowserSettingsPrivateSpaceAccessRow(
                space: space,
                accessController: accessController
            )
        }
        .accessibilityIdentifier("settings-private-space-lock")
    }
}
