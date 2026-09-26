import Foundation

/// One stateless core policy call. Raw values are the core's spellings in
/// `PolicyOperation.cs`.
enum BrowserPolicyOperation: String, Codable, Sendable {
    case limits
    case onboardingCompletion = "onboarding.completion"
    case onboardingGuide = "onboarding.guide"
    case residencyProcessRecovery = "residency.process_recovery"
    case residencyReleaseLimit = "residency.release_limit"
    case residencyReleasePlan = "residency.release_plan"
    case setupReconcile = "setup.reconcile"
    case setupSpace = "setup.space"
    case setupTab = "setup.tab"
}
