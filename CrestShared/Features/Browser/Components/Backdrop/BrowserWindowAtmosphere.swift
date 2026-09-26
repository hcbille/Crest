import SwiftUI

struct BrowserWindowAtmosphere: View {
    // MARK: - Variables

    /// The look of the Space the window shows, or nil for none.
    let branding: BrowserSpaceBranding?

    private var platformBackground: Color {
        BrowserPlatformWindowAtmosphereStyle.backgroundColor
    }

    // MARK: - Initializers

    init(space: SpaceModel?) {
        branding = space.map { BrowserSpaceBranding(look: $0.settings.look) }
    }

    /// A Space of the session copy. TRANSITIONAL until the Quick Window reads
    /// its Space from the read model.
    init(space: BrowserSpace?) {
        branding = space?.branding
    }

    var body: some View {
        ZStack {
            platformBackground
            if let branding {
                BrowserSpaceBannerBackground(branding: branding)
            }
        }
        .accessibilityHidden(true)
    }
}
