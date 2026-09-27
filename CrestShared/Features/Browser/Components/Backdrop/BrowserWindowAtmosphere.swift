import SwiftUI

struct BrowserWindowAtmosphere: View {
    // MARK: - Variables

    /// The look of the Space the window shows, or nil for none.
    let branding: SpaceBranding?

    private var platformBackground: Color {
        BrowserPlatformWindowAtmosphereStyle.backgroundColor
    }

    // MARK: - Initializers

    init(space: SpaceModel?) {
        branding = space.map(\.settings.look)
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
