import SwiftUI

struct BrowserOnboardingReviewSpaceControls: View {
    let flow: BrowserOnboardingFlow
    let application: ImportSource?
    let spaces: [BrowserImportSpaceReview]
    let review: BrowserImportSpaceReview

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 14) {
                BrowserOnboardingReviewSourcePicker(
                    applicationName: application?.title ?? "browser",
                    spaces: spaces,
                    currentSpaceID: review.id,
                    sourceSpaceName: review.sourceSpace.settings.name,
                    show: { flow.shownReviewSpaceID = $0 }
                )

                Button(action: toggleSpaceInclusion) {
                    Image(
                        systemName: review.isIncluded ? "arrow.right" : "xmark"
                    )
                }
                .buttonStyle(
                    .crestIcon(
                        tint: BrowserOnboardingPalette.coral,
                        isProminent: true
                    )
                )
                .accessibilityLabel(
                    review.isIncluded
                        ? "Skip this Space"
                        : "Include this Space"
                )

                BrowserOnboardingReviewDestinationPicker(
                    spaces: flow.destinationSpaces,
                    destination: destinationBinding,
                    destinationName: flow.destinationName(
                        for: review.destination
                    )
                )
            }
            .offset(y: -10)

            Toggle("Import this Space", isOn: spaceInclusionBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(BrowserOnboardingPalette.coral)

            Text(review.isIncluded ? "Move Space" : "Skip Space")
                .font(BrowserOnboardingTypography.sans(10, weight: .bold))
                .foregroundStyle(BrowserOnboardingPalette.inkSoft)

            if application?.suppliesPasswords == true {
                Divider()
                    .frame(width: 74)
                    .padding(.vertical, 4)

                Label(
                    flow.passwordCountLabel(for: review),
                    systemImage: "key.fill"
                )
                .font(BrowserOnboardingTypography.sans(10, weight: .bold))
                .foregroundStyle(BrowserOnboardingPalette.inkSoft)

                Toggle(
                    "Import passwords for \(review.sourceSpace.settings.name)",
                    isOn: passwordInclusionBinding
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(BrowserOnboardingPalette.coral)
                .disabled(
                    !review.isIncluded || review.record.passwordCount == 0
                )
                .accessibilityValue(
                    review.includesPasswords ? "On" : "Off"
                )
            }
        }
        .frame(width: 228)
    }

    private var destinationBinding: Binding<BrowserImportDestination> {
        Binding(
            get: { review.destination },
            set: { flow.setDestination($0, for: review.id) }
        )
    }

    private var spaceInclusionBinding: Binding<Bool> {
        Binding(
            get: { review.isIncluded },
            set: { flow.setSpaceIncluded($0, in: review.id) }
        )
    }

    private var passwordInclusionBinding: Binding<Bool> {
        Binding(
            get: { review.includesPasswords },
            set: { flow.setPasswordsIncluded($0, in: review.id) }
        )
    }

    private func toggleSpaceInclusion() {
        flow.setSpaceIncluded(!review.isIncluded, in: review.id)
    }
}

private struct BrowserOnboardingReviewSourcePicker: View {
    let applicationName: String
    let spaces: [BrowserImportSpaceReview]
    let currentSpaceID: UUID
    let sourceSpaceName: String
    let show: (UUID) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("From \(applicationName)")
                .font(.caption)
                .foregroundStyle(BrowserOnboardingPalette.inkSoft)

            Picker("Source Space", selection: selection) {
                ForEach(spaces) { item in
                    BrowserSpaceIdentityLabel(space: item.sourceSpace).tag(item.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.regular)
            .tint(BrowserOnboardingPalette.coral)
            .frame(width: 80)
            .accessibilityValue(sourceSpaceName)
        }
    }

    private var selection: Binding<UUID> {
        Binding(
            get: { currentSpaceID },
            set: { show($0) }
        )
    }
}

private struct BrowserOnboardingReviewDestinationPicker: View {
    let spaces: [SpaceModel]
    @Binding var destination: BrowserImportDestination
    let destinationName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Into Crest")
                .font(.caption)
                .foregroundStyle(BrowserOnboardingPalette.inkSoft)

            Picker("Destination Space", selection: $destination) {
                Text("New Space").tag(BrowserImportDestination.newSpace)
                ForEach(spaces) { space in
                    BrowserSpaceIdentityLabel(space: space).tag(
                        BrowserImportDestination.existing(space.id)
                    )
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.regular)
            .tint(BrowserOnboardingPalette.coral)
            .frame(width: 80)
            .accessibilityValue(destinationName)
        }
    }
}
