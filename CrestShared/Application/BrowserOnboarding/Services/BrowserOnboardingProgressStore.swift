import Foundation
import Observation

/// The launch gate setup holds shut until this device completes setup.
///
/// The core keeps whether the device completed setup in its device store,
/// having adopted what an installed release kept, and marks it when setup
/// finishes; this reads it. A launch that forces the welcome or setup, as a
/// review or test launch does, holds the gate shut until setup finishes in
/// this run.
@Observable
@MainActor
final class BrowserOnboardingProgressStore {
    // MARK: - Variables

    @ObservationIgnored let core: CrestCore
    /// Whether this launch forces setup whatever the device completed.
    let forcesSetup: Bool
    /// Whether this launch holds the gate shut until setup finishes in it.
    private var forcesGate: Bool

    /// Whether the device has completed setup, as far as this launch asks.
    var hasCompletedSetup: Bool {
        !forcesSetup && core.state.setupCompleted == true
    }

    var isLaunchGateActive: Bool {
        forcesGate || core.state.setupCompleted != true
    }

    var shouldPresentWelcome: Bool { isLaunchGateActive }

    // MARK: - Initializers

    /// A gate over `core`, which has adopted whether the device completed
    /// setup. `forceWelcome` and `forceSetup` hold it shut for this launch.
    init(core: CrestCore, forceWelcome: Bool = false, forceSetup: Bool = false) {
        self.core = core
        forcesSetup = forceSetup
        forcesGate = forceWelcome || forceSetup
    }

    // MARK: - Actions - Finishing

    /// Setup finished in this run: the gate opens.
    func setupFinished() {
        forcesGate = false
    }
}
