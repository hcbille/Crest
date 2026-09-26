import SwiftUI

struct MobileBrowserOnboardingView: View {
    let request: BrowserOnboardingRequest
    let browser: BrowserStore
    @Bindable var cloudSync: BrowserCloudSyncController
    @Bindable var progress: BrowserOnboardingProgressStore
    @Bindable var coordinator: BrowserOnboardingCoordinator
    let tutorialPersonalSpace: BrowserSpace
    let tutorialWorkSpace: BrowserSpace
    let spaceAccess: BrowserSpaceAccessController
    let didOpenGettingStarted: (BrowserTabRuntimeAssignment) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var step: MobileBrowserOnboardingStep
    /// The manual setup the core holds, which it keeps for the next launch
    /// until setup finishes.
    @State private var setup: BrowserManualSetupModel
    @State private var selectedSpaceID: SpaceID?
    @State private var errorMessage: String?
    @State private var completionTask: Task<Void, Never>?

    init(
        request: BrowserOnboardingRequest,
        browser: BrowserStore,
        cloudSync: BrowserCloudSyncController,
        progress: BrowserOnboardingProgressStore,
        coordinator: BrowserOnboardingCoordinator,
        spaceAccess: BrowserSpaceAccessController = BrowserSpaceAccessController(),
        didOpenGettingStarted: @escaping (BrowserTabRuntimeAssignment) -> Void = { _ in },
        tutorialPersonalSpace: BrowserSpace =
            MobileOnboardingPreviewFixtures.tutorialPersonalSpace,
        tutorialWorkSpace: BrowserSpace =
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
        _step = State(
            initialValue: MobileBrowserOnboardingPolicy.initialStep(for: request)
        )
    }

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
            progress: progress,
            appeared: { startManualSetup(for: request) },
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
            opensGettingStarted: progress.willOpenGettingStarted(for: request.entryPoint),
            setupSecondaryTitle: setupSecondaryTitle,
            welcomePrimaryAction: handleWelcomeAction,
            advance: advance,
            setupSecondaryAction: handleSetupSecondaryAction,
            finish: finishManualSetup,
            close: close,
            reviewFeatures: { move(to: .featureSpaces) }
        )
    }

    private var welcomeAction: BrowserOnboardingWelcomeAction {
        BrowserOnboardingWelcomePolicy.action(
            progressIsChecking: progress.isChecking,
            cloudPhase: cloudSync.phase,
            hasCompletedSetup: progress.hasCompletedSetup,
            entryPoint: request.entryPoint
        )
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

    private var setupSecondaryTitle: String {
        request.entryPoint.isGuidedSetup ? "Back" : "Cancel"
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

    private func advance() {
        guard let next = MobileBrowserOnboardingPolicy.nextStep(after: step) else {
            return
        }
        move(to: next)
    }

    private func handleSetupSecondaryAction() {
        if request.entryPoint.isGuidedSetup {
            move(to: .welcome)
        } else {
            close()
        }
    }

    private func move(to newStep: MobileBrowserOnboardingStep) {
        if reduceMotion {
            step = newStep
        } else {
            withAnimation(
                BrowserVisualAccessibilityPolicy.animation(
                    CrestMotion.selection,
                    reduceMotion: reduceMotion
                )
            ) {
                step = newStep
            }
        }
    }

    private func welcomeStatus(_ action: BrowserOnboardingWelcomeAction) -> String {
        if action == .checking {
            return "Checking iCloud for an existing Crest setup…"
        }
        if action == .open {
            return "Your existing Spaces are ready."
        }
        if !browser.session.hasDisposableSeedState {
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
        startManualSetup(for: request)
        move(to: MobileBrowserOnboardingPolicy.initialStep(for: request))
    }

    /// Goes on with the manual setup the core kept, following Spaces changed
    /// meanwhile, or starts one; a rerun always starts over.
    private func startManualSetup(for request: BrowserOnboardingRequest) {
        setup.begin(workspaceID: browser.family.workspaceID, startsOver: request.entryPoint == .rerun)
        selectedSpaceID = setup.spaces.first?.spaceID
    }

    private func finishManualSetup() {
        do {
            _ = try browser.manualSetupPreview()
            completeSetup(appliesManualSetup: true)
        } catch {
            errorMessage = error.personFacingDescription
        }
    }

    private func completeSetup(appliesManualSetup: Bool = false) {
        guard completionTask == nil else { return }
        completionTask = Task { @MainActor in
            let result = await BrowserOnboardingCompletion.complete(
                request: request, browser: browser, progress: progress, spaceAccess: spaceAccess,
                appliesManualSetup: appliesManualSetup,
                willComplete: { guide in
                    if let guide { didOpenGettingStarted(guide) }
                    coordinator.isMobilePresented = false
                })
            guard !Task.isCancelled else { return }
            completionTask = nil
            switch result {
            case .completed:
                errorMessage = nil
            case .cancelled:
                errorMessage = "Unlock your first Space to open Getting Started."
            case .sourceChanged:
                errorMessage = "Your Spaces changed. Review setup and try again."
            }
        }
    }

    private func close() {
        coordinator.isMobilePresented = false
    }
}

#Preview("Mobile Onboarding — Root") {
    let fixture = MobileBrowserPreviewFixture()
    let progress = BrowserOnboardingProgressStore(
        persistence: InMemoryBrowserOnboardingProgressPersistence(),
        forceWelcome: true
    )
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
