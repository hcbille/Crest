import SwiftUI

struct BrowserOnboardingImportPage: View {
    let sources: [BrowserInstalledImportSource]
    let selectedApplications: Set<ImportSource>
    let isReading: Bool
    let isLocked: Bool
    let failure: BrowserOnboardingFailureText?
    let accessLabel: (BrowserInstalledImportSource) -> String
    let toggleSelection: (ImportSource) -> Void
    let beginManualSetup: () -> Void
    let continueImport: () -> Void
    let back: BrowserOnboardingBackAction

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("IMPORT")
                        .font(
                            BrowserOnboardingTypography.sans(
                                11,
                                weight: .bold
                            )
                        )
                        .tracking(2.2)
                        .foregroundStyle(BrowserOnboardingPalette.coral)
                    Text("Choose what to bring over")
                        .font(BrowserOnboardingTypography.display(40))
                        .foregroundStyle(BrowserOnboardingPalette.ink)
                    Text(
                        "Crest found these browsers on your Mac. You’ll review every Space and tab next."
                    )
                    .font(
                        BrowserOnboardingTypography.sans(16, weight: .medium)
                    )
                    .foregroundStyle(BrowserOnboardingPalette.inkSoft)
                    .multilineTextAlignment(.center)
                }

                if sources.isEmpty {
                    ContentUnavailableView(
                        "No Supported Browsers Found",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text(
                            "You can still set up Spaces manually."
                        )
                    )
                } else {
                    BrowserInstalledImportSourceGrid(
                        sources: sources,
                        selectedApplications: selectedApplications,
                        isLocked: isLocked,
                        accessLabel: accessLabel,
                        toggleSelection: toggleSelection
                    )
                }

                if isReading {
                    ProgressView("Building your review…")
                        .controlSize(.large)
                }
                if let failure {
                    Label {
                        BrowserOnboardingFailureMessage(message: failure)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("onboarding-import-error")
                }
            }
            .padding(36)
            .frame(
                maxWidth: .infinity,
                maxHeight: BrowserImportPreviewControls.usesAnchoredImportFooter
                    ? .infinity
                    : nil,
                alignment: .center
            )

            HStack {
                if back.closes {
                    Button("Close", action: back.action)
                        .buttonStyle(BrowserOnboardingSecondaryButtonStyle())
                        .disabled(isLocked)
                        .accessibilityIdentifier("onboarding-import-close")
                } else {
                    Button("Back", action: back.action)
                        .buttonStyle(BrowserOnboardingSecondaryButtonStyle())
                        .disabled(isLocked)
                        .accessibilityIdentifier("onboarding-back")
                }
                Spacer()
                BrowserOnboardingImportSelectionAction(
                    hasSelection: !selectedApplications.isEmpty,
                    skip: beginManualSetup,
                    continueImport: continueImport
                )
                .disabled(isLocked)
            }
            .padding(18)
            .background(BrowserOnboardingPalette.paper)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(BrowserOnboardingPalette.line)
                    .frame(height: 1)
            }
        }
        .background(BrowserOnboardingPalette.parchment)
    }
}
