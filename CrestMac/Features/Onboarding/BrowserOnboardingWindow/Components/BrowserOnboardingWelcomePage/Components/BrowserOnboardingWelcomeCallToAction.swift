import SwiftUI

struct BrowserOnboardingWelcomeCallToAction: View {
    let action: BrowserOnboardingWelcomeAction
    let cloudStatusDetail: String
    let perform: () -> Void
    let setUpWithoutCloud: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: perform) {
                HStack {
                    if action.waitsOnCloud {
                        ProgressView().controlSize(.small)
                    }
                    Text(action.opensCrest ? "Open Crest" : "Continue")
                    Image(systemName: "arrow.right")
                }
                .frame(minWidth: 150)
            }
            .buttonStyle(BrowserOnboardingPrimaryButtonStyle())
            .controlSize(.large)
            .disabled(action.waitsOnCloud)
            .accessibilityLabel(
                action.opensCrest ? Text("Open Crest") : Text("Continue")
            )
            .accessibilityIdentifier("onboarding-welcome-continue")

            Text(
                action.waitsOnCloud
                    ? "Checking iCloud for an existing Crest setup…"
                    : cloudStatusDetail
            )
            .font(BrowserOnboardingTypography.sans(11, weight: .medium))
            .foregroundStyle(BrowserOnboardingPalette.inkSoft.opacity(0.72))

            if action.offersSetupWithoutCloud {
                Button("Set Up Without iCloud", action: setUpWithoutCloud)
                    .buttonStyle(.crestTertiary)
                    .accessibilityIdentifier("onboarding-welcome-setup-without-icloud")
            }
        }
    }
}
