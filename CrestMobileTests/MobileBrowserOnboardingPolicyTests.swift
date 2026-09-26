import XCTest

@testable import CrestMobile

final class MobileBrowserOnboardingPolicyTests: XCTestCase {
    func testAutomaticWelcomeIsSuppressedForAnIsolatedTestLaunch() {
        XCTAssertFalse(
            MobileBrowserAutomaticOnboardingPolicy.shouldPresent(
                forceOnboarding: false,
                usesIsolatedLaunch: true
            )
        )
    }

    func testExplicitOnboardingFixtureOverridesLaunchIsolation() {
        XCTAssertTrue(
            MobileBrowserAutomaticOnboardingPolicy.shouldPresent(
                forceOnboarding: true,
                usesIsolatedLaunch: true
            )
        )
    }

    func testProductionLaunchCanPresentTheAutomaticWelcome() {
        XCTAssertTrue(
            MobileBrowserAutomaticOnboardingPolicy.shouldPresent(
                forceOnboarding: false,
                usesIsolatedLaunch: false
            )
        )
    }

    func testLaunchGateOnlyReplacesTheBrowserOnAnIncompleteInstall() {
        XCTAssertTrue(
            MobileBrowserAutomaticOnboardingPolicy.showsLaunchGate(
                automaticallyPresentsOnboarding: true,
                isLaunchGateActive: true
            )
        )
        XCTAssertFalse(
            MobileBrowserAutomaticOnboardingPolicy.showsLaunchGate(
                automaticallyPresentsOnboarding: true,
                isLaunchGateActive: false
            )
        )
        XCTAssertFalse(
            MobileBrowserAutomaticOnboardingPolicy.showsLaunchGate(
                automaticallyPresentsOnboarding: false,
                isLaunchGateActive: true
            )
        )
    }

}
