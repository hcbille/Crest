namespace CrestCore.Application;

internal enum PolicyOperation {
    Unknown,
    OnboardingCompletion,
    OnboardingGuide,
    ResidencyReleaseLimit,
    ResidencyReleasePlan,
}

internal static class PolicyOperationCodes {
    #region Actions - Decoding

    public static PolicyOperation Parse(string? value) => value switch {
        "onboarding.completion" => PolicyOperation.OnboardingCompletion,
        "onboarding.guide" => PolicyOperation.OnboardingGuide,
        "residency.release_limit" => PolicyOperation.ResidencyReleaseLimit,
        "residency.release_plan" => PolicyOperation.ResidencyReleasePlan,
        _ => PolicyOperation.Unknown
    };

    #endregion
}
