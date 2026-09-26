import Foundation

extension BrowserStore {
    // MARK: - Actions - Launch

    /// The destination this launch's first window opens: the core's launch
    /// plan applies the saved startup preference this workspace keeps, the
    /// launch's isolation and any active setup; `hasActiveLaunchGate` is true
    /// while first-run setup owns the first window. A workspace that keeps no
    /// preferences opens the Start Page.
    func startupBehavior(for environment: BrowserLaunchEnvironment, hasActiveLaunchGate: Bool = false)
        -> BrowserStartupBehavior
    {
        let plan = LaunchPlan(
            workspaceID: family.workspaceID, platform: .current, environment: environment.coreEnvironment,
            hasActiveLaunchGate: hasActiveLaunchGate)
        guard let decision = try? core.query(plan) else {
            return BrowserStartupBehavior(coreTerm: LaunchDecision.unavailable.startup) ?? .showStartPage
        }
        return BrowserStartupBehavior(coreTerm: decision.startup) ?? .showStartPage
    }
}
