using System.Text.Json;
using System.Text.Json.Nodes;

using CrestCore.Domain;

using Requests = CrestCore.Application.SetupPolicyRequests;

namespace CrestCore.Application;

public static partial class NativePolicyEvaluator {
    #region Actions - Setup

    /// Null when the operation is not an onboarding policy. These decide what
    /// finishing setup does; the device holds the manual setup itself.
    private static JsonObject? EvaluateSetup(PolicyOperation operation, JsonElement request) => operation switch {
        PolicyOperation.OnboardingCompletion => CompleteOnboarding(Requests.Completion.Decode(request)),
        PolicyOperation.OnboardingGuide => SetupCodes.GuideAnswer(
            OnboardingCompletionPolicy.ConfirmsGuide(Requests.Guide.Decode(request).Facts)),
        _ => null
    };

    private static JsonObject CompleteOnboarding(Requests.Completion request) => SetupCodes.OutcomeAnswer(
        OnboardingCompletionPolicy.Decide(request.EntryPoint, request.HasCompletedSetup, request.IsPrivateBrowsing));

    #endregion
}
