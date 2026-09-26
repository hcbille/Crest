/// What the welcome offers: to wait while iCloud is checked, to set Crest
/// up, or to open Crest once setup is done.
enum BrowserOnboardingWelcomeAction: Equatable, Sendable {
    case checking
    case setup
    case open

    /// What the welcome offers for `flow`, as the core published it, while
    /// iCloud sync is in `cloudPhase`. A launch that `forcesSetup` always
    /// offers setup.
    init(flow: SetupFlowState?, cloudPhase: BrowserCloudSyncPhase, forcesSetup: Bool = false) {
        if cloudPhase == .checking || flow == nil {
            self = .checking
        } else {
            self = flow?.opensCrestFromWelcome == true && !forcesSetup ? .open : .setup
        }
    }
}
