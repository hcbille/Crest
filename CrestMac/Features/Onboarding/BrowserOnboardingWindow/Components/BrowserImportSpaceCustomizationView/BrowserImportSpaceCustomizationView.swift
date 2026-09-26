import SwiftUI

/// Gives a reviewed Space a name, symbol and look before it is imported.
/// Setup holds each choice.
struct BrowserImportSpaceCustomizationView: View {
    let flow: BrowserOnboardingFlow
    let spaceID: SpaceID
    let previewSpace: BrowserSpace?
    let done: () -> Void

    @ViewBuilder
    var body: some View {
        if review != nil {
            BrowserImportSpaceCustomizationContent(
                previewSpace: previewSpace,
                name: binding(get: \.name) { current, name in
                    SpaceCustomization(
                        name: name, symbol: current.symbol, accent: current.accent, branding: current.branding)
                },
                symbol: binding(get: \.symbol) { current, symbol in
                    SpaceCustomization(
                        name: current.name, symbol: symbol, accent: current.accent, branding: current.branding)
                },
                branding: brandingBinding,
                done: done
            )
        }
    }

    private var review: BrowserImportSpaceReview? {
        flow.reviewSpaces.first { $0.id == spaceID }
    }

    /// A binding to one part of the Space's customization, which `set`
    /// replaces in the rest.
    private func binding(
        get: KeyPath<SpaceCustomization, String>,
        set: @escaping (SpaceCustomization, String) -> SpaceCustomization
    ) -> Binding<String> {
        Binding(
            get: { review?.customization[keyPath: get] ?? "" },
            set: { value in
                guard let current = review?.customization else { return }
                flow.customize(spaceID, as: set(current, value))
            }
        )
    }

    private var brandingBinding: Binding<BrowserSpaceBranding> {
        Binding(
            get: {
                review.map { BrowserSpaceBranding(look: $0.customization.branding) }
                    ?? previewSpace?.branding
                    ?? .initial(accent: .indigo, symbol: "square.grid.2x2")
            },
            set: { branding in
                guard let current = review?.customization else { return }
                flow.customize(
                    spaceID,
                    as: SpaceCustomization(
                        name: current.name, symbol: current.symbol, accent: current.accent, branding: branding.core))
            }
        )
    }
}
