import SwiftUI

struct BrowserSettingsDestinationPage: View {
    @Environment(\.browserMacWindows) private var windows

    let destination: BrowserSettingsDestination
    var tabAssignment: BrowserTabRuntimeAssignment? = nil
    let browser: BrowserStore
    let pages: BrowserPagePool
    let cloudSync: BrowserCloudSyncController
    let spaceAccess: BrowserSpaceAccessController
    let dataDeleter: any BrowserSpaceDataDeleting
    let shortcuts: BrowserShortcutStore
    let spaceSettingsPresentation: BrowserSpaceSettingsPresentationState
    @Binding var searchText: String

    var body: some View {
        BrowserSettingsPage(destination: destination) {
            BrowserSettingsDestinationRouter(
                destination: destination,
                browser: browser,
                spaceAccess: spaceAccess,
                dataDeleter: dataDeleter,
                cloudSync: cloudSync,
                downloadCenter: pages.downloadCenter,
                permissionCenter: pages.permissionCenter,
                contentBlockingErrorDescription:
                    pages.contentBlockingErrorDescription,
                setupActions: setupActions,
                passwordLayout: .macOSPage,
                passwordSearchText: $searchText,
                shortcuts: shortcuts,
                requestedSpaceID: requestedSpaceID,
                requestRevision: acceptsExternalRoute ? spaceSettingsPresentation.revision : 0,
                featureFlagsSpace: featureFlagsSpace
            )
        }
    }

    private var acceptsExternalRoute: Bool {
        guard let tabAssignment else { return true }
        return spaceSettingsPresentation.requestedAssignment
            == BrowserSpaceRuntimeAssignment(
                spaceID: tabAssignment.spaceID, profileID: tabAssignment.profileID)
    }

    private var requestedSpaceID: UUID? {
        acceptsExternalRoute ? spaceSettingsPresentation.requestedSpaceID(in: browser) : nil
    }

    private var featureFlagsSpace: SpaceModel? {
        let space: SpaceModel?
        if let tabAssignment {
            space = browser.spaceModel(
                matching: BrowserSpaceRuntimeAssignment(
                    spaceID: tabAssignment.spaceID, profileID: tabAssignment.profileID))
        } else {
            space = browser.shownSpace
        }
        guard let space,
            !spaceAccess.isLocked(space)
        else { return nil }
        return space
    }

    private var setupActions: [BrowserAdvancedSetupAction] {
        [
            .init(
                id: "rerun-onboarding",
                title: "Rerun onboarding",
                symbol: "arrow.counterclockwise",
                help: "Restart setup from the welcome screen"
            ) {
                presentSetup(.rerun)
            },
            .init(
                id: "manual-setup",
                title: "Review & Customize Setup…",
                symbol: "sparkles",
                help: "Customize current Spaces or add new Spaces"
            ) {
                presentSetup(.manualSetup)
            },
            .init(
                id: "import-browser",
                title: "Import from Another Browser…",
                symbol: "arrow.down.app",
                help: "Review another browser and merge selected tabs into your current Spaces"
            ) {
                presentSetup(.importBrowser)
            },
        ]
    }

    private func presentSetup(_ request: BrowserOnboardingRequest) {
        windows?.openOnboardingWindow(request)
    }
}
