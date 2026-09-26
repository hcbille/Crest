import SwiftUI

/// The page for the step setup is on. Back leads where the core says, or
/// closes setup where it leads nowhere.
struct BrowserOnboardingStepContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let cloudSync: BrowserCloudSyncController
    let progress: BrowserOnboardingProgressStore
    let flow: BrowserOnboardingFlow
    @Binding var selectedManualSpaceID: SpaceID?
    @Binding var customizationSpaceID: SpaceID?
    let close: () -> Void
    let openCrest: () -> Void

    var body: some View {
        switch flow.step {
        case .welcome:
            BrowserOnboardingWelcomePage(
                action: BrowserOnboardingWelcomeAction(
                    flow: flow.state, cloudPhase: cloudSync.phase, forcesSetup: progress.forcesSetup),
                cloudPhase: cloudSync.phase,
                hasCompletedSetup: progress.hasCompletedSetup,
                hasDisposableSeedState: flow.browser.session.hasDisposableSeedState,
                continueSetup: {
                    if let next = flow.state?.nextStep { transition(to: next) }
                },
                openCrest: openCrest
            )
        case .importBrowser:
            BrowserOnboardingImportPage(
                sources: flow.installedSources,
                selectedApplications: flow.selectedImportApplications,
                isReading: flow.isReading,
                isLocked: flow.isImportSelectionLocked,
                failure: flow.failure?.message,
                accessLabel: flow.importAccessLabel,
                toggleSelection: flow.toggleImportSelection,
                beginManualSetup: beginManualSetup,
                continueImport: flow.continueImportQueue,
                back: back
            )
        case .review:
            BrowserOnboardingReviewPage(
                flow: flow,
                browserSession: flow.browser.session,
                sources: flow.installedSources,
                customizationSpaceID: $customizationSpaceID,
                back: back
            )
        case .manualSetup:
            BrowserOnboardingManualSetupPage(
                flow: flow,
                opensGettingStarted: flow.state?.opensGuide == true,
                selectedSpaceID: $selectedManualSpaceID,
                back: back.action,
                openCrest: openCrest
            )
        case .complete:
            BrowserOnboardingCompletionPage(
                summary: flow.completionSummary,
                openCrest: openCrest
            )
        default:
            EmptyView()
        }
    }

    /// What Back does from the step: the step the core names, or closing.
    private var back: BrowserOnboardingBackAction {
        guard let step = flow.state?.backStep else { return BrowserOnboardingBackAction(closes: true, action: close) }
        return BrowserOnboardingBackAction(closes: false, action: { transition(to: step) })
    }

    private func beginManualSetup() {
        flow.beginManualSetup()
        flow.manualSetup.repairSelection($selectedManualSpaceID)
    }

    private func transition(to step: SetupStep) {
        withAnimation(motion(CrestMotion.onboardingStep)) {
            flow.show(step)
        }
        if step == .manualSetup { flow.manualSetup.repairSelection($selectedManualSpaceID) }
    }

    private func motion(_ animation: Animation) -> Animation? {
        BrowserVisualAccessibilityPolicy.animation(
            animation,
            reduceMotion: reduceMotion
        )
    }
}

/// What a page's Back button does: go back a step, or close setup where the
/// entry did not pass through one.
struct BrowserOnboardingBackAction {
    /// Whether Back closes setup, which the button then says.
    let closes: Bool
    let action: () -> Void
}
