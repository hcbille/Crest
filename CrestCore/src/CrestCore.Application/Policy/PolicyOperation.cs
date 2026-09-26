namespace CrestCore.Application;

internal enum PolicyOperation {
    Unknown,
    Limits,
    OnboardingCompletion,
    OnboardingGuide,
    ResidencyReleaseLimit,
    ResidencyReleasePlan,
    SetupReconcile,
    SetupSpace,
    SetupTab,
}

internal static class PolicyOperationCodes {
    #region Actions - Decoding

    public static PolicyOperation Parse(string? value) => value switch {
        "limits" => PolicyOperation.Limits,
        "onboarding.completion" => PolicyOperation.OnboardingCompletion,
        "onboarding.guide" => PolicyOperation.OnboardingGuide,
        "residency.release_limit" => PolicyOperation.ResidencyReleaseLimit,
        "residency.release_plan" => PolicyOperation.ResidencyReleasePlan,
        "setup.reconcile" => PolicyOperation.SetupReconcile,
        "setup.space" => PolicyOperation.SetupSpace,
        "setup.tab" => PolicyOperation.SetupTab,
        _ => PolicyOperation.Unknown
    };

    #endregion
}
