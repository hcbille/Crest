import SwiftUI

struct BrowserOnboardingManualSetupPage: View {
    let flow: BrowserOnboardingFlow
    let opensGettingStarted: Bool
    @Binding var selectedSpaceID: UUID?
    let back: () -> Void
    let openCrest: () -> Void

    var body: some View {
        BrowserSpaceSetupWizard(
            setup: flow.manualSetup,
            selectedSpaceID: $selectedSpaceID,
            opensGettingStarted: opensGettingStarted,
            back: back,
            finish: openCrest
        )
        .overlay(alignment: .bottom) {
            if let message = flow.failure?.message {
                BrowserOnboardingFailureMessage(message: message)
                    .foregroundStyle(.red)
                    .padding(.bottom, 76)
            }
        }
        .accessibilityIdentifier("manual-setup-editor")
    }
}
