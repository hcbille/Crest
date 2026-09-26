namespace CrestCore.Application;

internal enum PolicyOperation {
    Unknown,
    ResidencyReleaseLimit,
    ResidencyReleasePlan,
}

internal static class PolicyOperationCodes {
    #region Actions - Decoding

    public static PolicyOperation Parse(string? value) => value switch {
        "residency.release_limit" => PolicyOperation.ResidencyReleaseLimit,
        "residency.release_plan" => PolicyOperation.ResidencyReleasePlan,
        _ => PolicyOperation.Unknown
    };

    #endregion
}
