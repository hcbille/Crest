using System.Text.Json;

using CrestCore.Contracts;
using CrestCore.Domain;

using static CrestCore.Application.PolicyFields;

namespace CrestCore.Application;

/// Typed requests for the onboarding policy operations: the finish being
/// judged.
internal static class SetupPolicyRequests {
    #region Actions - Decoding

    public sealed record Completion(OnboardingEntryPoint EntryPoint, bool HasCompletedSetup, bool IsPrivateBrowsing) {
        public static Completion Decode(JsonElement request) {
            Members(request, "entryPoint", "hasCompletedSetup", "isPrivateBrowsing");
            var entryPoint = SetupCodes.EntryPoint(Protocol.Text(request, "entryPoint", 32));
            bool completed = Flag(request, "hasCompletedSetup");
            return new(entryPoint, completed, Flag(request, "isPrivateBrowsing"));
        }
    }

    public sealed record Guide(OnboardingGuideFacts Facts) {
        public static Guide Decode(JsonElement request) {
            Members(request, "target", "originalFirst", "currentFirst", "originalTarget", "currentTarget", "previewFirst",
                "hasManualPlan", "locked");
            var target = SetupCodes.Identity(request, "target") ?? throw new ProtocolException(ProtocolErrorCodes.InvalidInput);
            return new(new OnboardingGuideFacts(target, SetupCodes.Identity(request, "originalFirst"), SetupCodes.Identity(request, "currentFirst"),
                SetupCodes.Identity(request, "originalTarget"), SetupCodes.Identity(request, "currentTarget"),
                SetupCodes.Identity(request, "previewFirst"), Flag(request, "hasManualPlan"), Flag(request, "locked")));
        }
    }

    #endregion
}
