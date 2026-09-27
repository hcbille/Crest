import SwiftUI

struct BrowserOnboardingWindow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    let request: BrowserOnboardingRequest
    let cloudSync: BrowserCloudSyncController
    let progress: BrowserOnboardingProgressStore
    let spaceAccess: BrowserSpaceAccessController
    private var hostClose: (() -> Void)?
    private var hostOpenBrowser: (() -> Void)?

    @State private var flow: BrowserOnboardingFlow
    @State private var selectedManualSpaceID: UUID?
    @State private var customizationSpaceID: UUID?

    init(
        request: BrowserOnboardingRequest,
        browser: BrowserStore,
        cloudSync: BrowserCloudSyncController,
        progress: BrowserOnboardingProgressStore,
        spaceAccess: BrowserSpaceAccessController,
        hostClose: (() -> Void)? = nil,
        hostOpenBrowser: (() -> Void)? = nil
    ) {
        self.init(
            request: request,
            cloudSync: cloudSync,
            progress: progress,
            spaceAccess: spaceAccess,
            flow: BrowserOnboardingFlow(request: request, browser: browser),
            hostClose: hostClose, hostOpenBrowser: hostOpenBrowser
        )
    }

    init(
        request: BrowserOnboardingRequest,
        cloudSync: BrowserCloudSyncController,
        progress: BrowserOnboardingProgressStore,
        spaceAccess: BrowserSpaceAccessController,
        flow: BrowserOnboardingFlow,
        hostClose: (() -> Void)? = nil,
        hostOpenBrowser: (() -> Void)? = nil
    ) {
        self.request = request
        self.cloudSync = cloudSync
        self.progress = progress
        self.spaceAccess = spaceAccess
        self.hostClose = hostClose
        self.hostOpenBrowser = hostOpenBrowser
        _flow = State(initialValue: flow)
        _selectedManualSpaceID = State(initialValue: flow.manualSetup.spaces.first?.spaceID)
        _customizationSpaceID = State(initialValue: nil)
    }

    var body: some View {
        BrowserOnboardingWindowContent(
            request: request,
            cloudSync: cloudSync,
            progress: progress,
            flow: flow,
            selectedManualSpaceID: $selectedManualSpaceID,
            customizationSpaceID: $customizationSpaceID,
            close: close,
            openCrest: openCrest
        )
        .environment(flow.browser.core)
    }

    private func close() {
        if let hostClose { hostClose() } else { dismiss() }
    }

    private func openCrest() {
        let reusesLaunchWindow = progress.isLaunchGateActive
        flow.completeSetup(progress: progress, spaceAccess: spaceAccess) {
            // Completing the gate turns its existing WindowGroup window into
            // the browser. Opening the scene again creates a second window.
            BrowserOnboardingLaunchGateWindow.restore()
            if let hostOpenBrowser {
                hostOpenBrowser()
            } else if !reusesLaunchWindow {
                openWindow(id: BrowserSceneID.browser.rawValue)
            }
            close()
        }
    }
}

#Preview("Onboarding Window") {
    let fixture = BrowserOnboardingWindowPreviewFixture()
    BrowserOnboardingWindow(
        request: fixture.request,
        cloudSync: fixture.cloudSync,
        progress: fixture.progress,
        spaceAccess: fixture.spaceAccess,
        flow: fixture.flow
    )
    .frame(width: 980, height: 660)
}
