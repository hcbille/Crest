import SwiftUI

/// Setup on iPhone and iPad. The core holds the step, where Back and Next
/// lead, the manual setup, and what finishing does; this draws the step and
/// finishes setup.
struct MobileBrowserOnboardingView: View {
    let request: BrowserOnboardingRequest
    let browser: BrowserStore
    @Bindable var cloudSync: BrowserCloudSyncController
    @Bindable var progress: BrowserOnboardingProgressStore
    @Bindable var coordinator: BrowserOnboardingCoordinator
    let tutorialPersonalSpace: SpaceModel
    let tutorialWorkSpace: SpaceModel
    let spaceAccess: BrowserSpaceAccessController
    let didOpenGettingStarted: (BrowserTabRuntimeAssignment) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The manual setup the core holds, which it keeps for the next launch
    /// until setup finishes.
    @State private var setup: BrowserManualSetupModel
    @State private var selectedSpaceID: SpaceID?
    @State private var errorMessage: String?
    @State private var completionTask: Task<Void, Never>?
    /// The step shown while finishing, which stays as the sheet goes.
    @State private var finishingStep: SetupStep?

    init(
        request: BrowserOnboardingRequest,
        browser: BrowserStore,
        cloudSync: BrowserCloudSyncController,
        progress: BrowserOnboardingProgressStore,
        coordinator: BrowserOnboardingCoordinator,
        spaceAccess: BrowserSpaceAccessController = BrowserSpaceAccessController(),
        didOpenGettingStarted: @escaping (BrowserTabRuntimeAssignment) -> Void = { _ in },
        tutorialPersonalSpace: SpaceModel =
            MobileOnboardingPreviewFixtures.tutorialPersonalSpace,
        tutorialWorkSpace: SpaceModel =
            MobileOnboardingPreviewFixtures.tutorialWorkSpace
    ) {
        self.request = request
        self.browser = browser
        self.cloudSync = cloudSync
        self.progress = progress
        self.coordinator = coordinator
        self.didOpenGettingStarted = didOpenGettingStarted
        self.spaceAccess = spaceAccess
        self.tutorialPersonalSpace = tutorialPersonalSpace
        self.tutorialWorkSpace = tutorialWorkSpace
        _setup = State(initialValue: BrowserManualSetupModel(core: browser.core))
    }

    /// Setup as the core holds it, or nil before it opens.
    private var flow: SetupFlowState? { browser.core.state.setupFlow }

    private var step: SetupStep { finishingStep ?? flow?.step ?? request.entryPoint.firstStep }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            MobileOnboardingCurrentPage(context: pageContext)
                .transition(.opacity)
        }
        .tint(.accentColor)
        .modifier(lifecycleModifier)
        .disabled(completionTask != nil)
        .onDisappear { completionTask?.cancel() }
    }

    private var lifecycleModifier: MobileOnboardingLifecycleModifier {
        MobileOnboardingLifecycleModifier(
            request: request,
            appeared: { start(request) },
            requestChanged: reset
        )
    }

    private var pageContext: MobileOnboardingPageContext {
        MobileOnboardingPageContext(
            step: step,
            welcomeAction: welcomeAction,
            welcomePrimaryTitle: welcomePrimaryTitle,
            welcomeStatus: welcomeStatus(welcomeAction),
            previewWidth: previewWidth,
            personalSpace: tutorialPersonalSpace,
            workSpace: tutorialWorkSpace,
            featureCloseTitle: featureCloseTitle,
            featureCloseAction: featureCloseAction,
            setup: setup,
            selectedSpaceID: $selectedSpaceID,
            errorMessage: errorMessage,
            opensGettingStarted: flow?.opensGuide == true,
            welcomePrimaryAction: handleWelcomeAction,
            advance: advance,
            setupSecondaryAction: back,
            finish: completeSetup,
            close: close,
            reviewFeatures: { move(to: .featureSpaces) }
        )
    }

    private var welcomeAction: BrowserOnboardingWelcomeAction {
        BrowserOnboardingWelcomeAction(flow: flow, cloudPhase: cloudSync.phase, forcesSetup: progress.forcesSetup)
    }

    private var welcomePrimaryTitle: String {
        switch welcomeAction {
        case .checking:
            "Checking iCloud"
        case .setup:
            "Get Started"
        case .open:
            "Open Crest"
        }
    }

    private var featureCloseTitle: String? {
        request.entryPoint == .firstRun ? nil : "Close"
    }

    private var featureCloseAction: (() -> Void)? {
        guard request.entryPoint != .firstRun else { return nil }
        return { close() }
    }

    private var previewWidth: CGFloat {
        horizontalSizeClass == .regular
            ? MobileOnboardingLayout.regularPreviewWidth
            : MobileOnboardingLayout.compactPreviewWidth
    }

    private func handleWelcomeAction() {
        switch welcomeAction {
        case .checking:
            return
        case .setup:
            advance()
        case .open:
            completeSetup()
        }
    }

    /// Goes on to the step the core says follows this one.
    private func advance() {
        guard let next = flow?.nextStep else { return }
        move(to: next)
    }

    /// Goes back to the step the core names, or closes setup where Back
    /// leads nowhere.
    private func back() {
        guard let previous = flow?.backStep else {
            close()
            return
        }
        move(to: previous)
    }

    private func move(to newStep: SetupStep) {
        withAnimation(
            BrowserVisualAccessibilityPolicy.animation(
                CrestMotion.selection,
                reduceMotion: reduceMotion
            )
        ) {
            _ = try? browser.core.send(ShowSetupStep(step: newStep))
        }
        setup.repairSelection($selectedSpaceID)
    }

    private func welcomeStatus(_ action: BrowserOnboardingWelcomeAction) -> String {
        if action == .checking {
            return "Checking iCloud for an existing Crest setup…"
        }
        if action == .open {
            return "Your existing Spaces are ready."
        }
        if browser.workspaceModel?.isDisposableSeed != true {
            return "Your existing Spaces are ready to customize."
        }
        if case .failed = cloudSync.phase {
            return "iCloud is unavailable right now; you can still set up this device."
        }
        return "No existing setup was found in iCloud."
    }

    private func reset(for request: BrowserOnboardingRequest) {
        completionTask?.cancel()
        completionTask = nil
        errorMessage = nil
        start(request)
    }

    /// Opens setup in the core for `request`. The core goes on with the
    /// manual setup it kept, following Spaces changed meanwhile; a rerun
    /// starts it over.
    private func start(_ request: BrowserOnboardingRequest) {
        finishingStep = nil
        _ = try? browser.core.send(StartSetup(workspaceID: browser.family.workspaceID, entry: request.entryPoint))
        setup.repairSelection($selectedSpaceID)
    }

    /// Finishes setup: the core applies the manual setup and completes setup
    /// on this device, and the guide opens where the core names it.
    private func completeSetup() {
        guard completionTask == nil else { return }
        finishingStep = step
        completionTask = Task { @MainActor in
            let result = await BrowserSetupFinish.finish(browser: browser, spaceAccess: spaceAccess)
            guard !Task.isCancelled else { return }
            completionTask = nil
            switch result {
            case .completed(let guide):
                errorMessage = nil
                progress.setupFinished()
                if let guide { didOpenGettingStarted(guide) }
                coordinator.isMobilePresented = false
            case .cancelled:
                finishingStep = nil
                errorMessage = String(localized: "Unlock your first Space to open Getting Started.")
            case .refused(let message):
                finishingStep = nil
                errorMessage = message
            }
        }
    }

    private func close() {
        coordinator.isMobilePresented = false
    }
}

#Preview("Mobile Onboarding — Root") {
    let fixture = MobileBrowserPreviewFixture()
    let progress = BrowserOnboardingProgressStore(core: fixture.browser.core, forceWelcome: true)
    MobileBrowserOnboardingView(
        request: BrowserOnboardingRequest(
            entryPoint: .firstRun,
            presentationID: UUID(
                uuid: (
                    0x34, 0xC8, 0x5B, 0x68, 0x41, 0xE4, 0x4A, 0x3C,
                    0xA4, 0xB9, 0x3F, 0x39, 0x72, 0x13, 0x3C, 0x42
                )
            )
        ),
        browser: fixture.browser,
        cloudSync: fixture.cloudSync,
        progress: progress,
        coordinator: fixture.onboardingCoordinator,
        tutorialPersonalSpace: fixture.alternateSpace,
        tutorialWorkSpace: fixture.space
    )
}
