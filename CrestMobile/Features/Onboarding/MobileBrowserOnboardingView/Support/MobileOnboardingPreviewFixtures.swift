import Foundation

/// The Spaces the feature pages draw, taken from the preview session.
enum MobileOnboardingPreviewFixtures {
    static var tutorialWorkSpace: BrowserSpace {
        guard let space = BrowserSession.preview.spaces.first else {
            preconditionFailure("The onboarding work preview requires one Space.")
        }
        return space
    }

    static var tutorialPersonalSpace: BrowserSpace {
        guard let space = BrowserSession.preview.spaces.dropFirst().first else {
            preconditionFailure("The onboarding personal preview requires two Spaces.")
        }
        return space
    }
}
