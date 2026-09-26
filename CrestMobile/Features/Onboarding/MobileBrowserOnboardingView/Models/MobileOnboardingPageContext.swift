import SwiftUI

struct MobileOnboardingPageContext {
    let step: MobileBrowserOnboardingStep
    let welcomeAction: BrowserOnboardingWelcomeAction
    let welcomePrimaryTitle: String
    let welcomeStatus: String
    let previewWidth: CGFloat
    let personalSpace: BrowserSpace
    let workSpace: BrowserSpace
    let featureCloseTitle: String?
    let featureCloseAction: (() -> Void)?
    let setup: BrowserManualSetupModel
    let selectedSpaceID: Binding<SpaceID?>
    let errorMessage: String?
    var opensGettingStarted = false
    let setupSecondaryTitle: String
    let welcomePrimaryAction: () -> Void
    let advance: () -> Void
    let setupSecondaryAction: () -> Void
    let finish: () -> Void
    let close: () -> Void
    let reviewFeatures: () -> Void
}
