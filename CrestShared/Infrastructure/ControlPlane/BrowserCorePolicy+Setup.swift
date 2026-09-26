import Foundation

/// What finishing setup does, as the core decides it.
enum BrowserOnboardingCompletionOutcome: String, Decodable {
    case sourceChanged
    case complete
    case openGuide
}

/// Onboarding completion rules owned by the portable core. The core holds the
/// manual setup itself; the workspace import applies it.
extension BrowserCorePolicy {
    // MARK: - Types

    private struct CompletionRequest: Encodable {
        let entryPoint: BrowserOnboardingEntryPoint
        let hasCompletedSetup: Bool
        let isPrivateBrowsing: Bool
    }

    private struct CompletionAnswer: Decodable {
        @BrowserCoreOptional var outcome: BrowserOnboardingCompletionOutcome?
    }

    private struct GuideRequest: Encodable {
        /// One Space identity in the core's spelling.
        struct Identity: Encodable {
            let spaceID: String
            let profileID: String

            init(_ assignment: BrowserSpaceRuntimeAssignment) {
                spaceID = assignment.spaceID.coreIdentifier
                profileID = assignment.profileID.coreIdentifier
            }
        }

        let target: Identity
        @BrowserCoreNullable var originalFirst: Identity?
        @BrowserCoreNullable var currentFirst: Identity?
        @BrowserCoreNullable var originalTarget: Identity?
        @BrowserCoreNullable var currentTarget: Identity?
        @BrowserCoreNullable var previewFirst: Identity?
        let hasManualPlan: Bool
        let locked: Bool
    }

    private struct GuideAnswer: Decodable {
        @BrowserCoreOptional var confirmed: Bool?
    }

    // MARK: - Actions - Setup

    /// Nil when the core cannot answer; the caller treats that as a changed source.
    static func onboardingCompletion(
        entryPoint: BrowserOnboardingEntryPoint, hasCompletedSetup: Bool,
        isPrivateBrowsing: Bool
    ) -> BrowserOnboardingCompletionOutcome? {
        let request = CompletionRequest(
            entryPoint: entryPoint, hasCompletedSetup: hasCompletedSetup, isPrivateBrowsing: isPrivateBrowsing)
        return evaluate(.onboardingCompletion, request, answer: CompletionAnswer.self)?.outcome
    }

    /// Whether the Getting Started guide may open in `target` after its Space
    /// unlocked. An unavailable core does not open it.
    static func confirmsOnboardingGuide(
        target: BrowserSpaceRuntimeAssignment,
        originalFirst: BrowserSpaceRuntimeAssignment?, currentFirst: BrowserSpaceRuntimeAssignment?,
        originalTarget: BrowserSpaceRuntimeAssignment?, currentTarget: BrowserSpaceRuntimeAssignment?,
        previewFirst: BrowserSpaceRuntimeAssignment?, hasManualPlan: Bool, isLocked: Bool
    ) -> Bool {
        let request = GuideRequest(
            target: GuideRequest.Identity(target),
            originalFirst: originalFirst.map(GuideRequest.Identity.init),
            currentFirst: currentFirst.map(GuideRequest.Identity.init),
            originalTarget: originalTarget.map(GuideRequest.Identity.init),
            currentTarget: currentTarget.map(GuideRequest.Identity.init),
            previewFirst: previewFirst.map(GuideRequest.Identity.init),
            hasManualPlan: hasManualPlan, locked: isLocked)
        return evaluate(.onboardingGuide, request, answer: GuideAnswer.self)?.confirmed ?? false
    }
}
