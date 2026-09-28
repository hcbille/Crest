/// What the settings call the account's state.
extension CloudAccountState {
    var description: String {
        switch self {
        case .available: "Available"
        case .noAccount: "Not signed in"
        case .restricted: "Restricted"
        case .temporarilyUnavailable: "Temporarily unavailable"
        case .couldNotDetermine: "Could not determine"
        default: "Checking"
        }
    }
}

/// Where iCloud sync stands, as the settings and onboarding show it, with a
/// failure's words.
enum BrowserCloudSyncPhase: Equatable, Sendable {
    case disabled
    case checking
    case ready
    case syncing
    case needsReconciliation
    case waitingForAccount
    case failed(String)

    var description: String {
        switch self {
        case .disabled: "Off"
        case .checking: "Checking iCloud"
        case .ready: "Ready"
        case .syncing: "Syncing"
        case .needsReconciliation: "Choose which copy to keep"
        case .waitingForAccount: "Waiting for iCloud"
        case .failed: "Needs attention"
        }
    }

    /// Whether iCloud's content is out of this device's reach: the check for
    /// it has not answered, no account is signed in, or sync failed.
    var keepsCloudOutOfReach: Bool {
        switch self {
        case .checking, .waitingForAccount, .failed: true
        case .disabled, .ready, .syncing, .needsReconciliation: false
        }
    }
}
