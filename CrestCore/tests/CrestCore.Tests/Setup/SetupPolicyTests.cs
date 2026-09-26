using System.Text;
using System.Text.Json.Nodes;

using CrestCore.Application;
using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

public sealed class SetupPolicyTests {
    private static JsonNode Evaluate(JsonObject request) {
        request["version"] = 1;
        return JsonNode.Parse(NativePolicyEvaluator.Evaluate(Encoding.UTF8.GetBytes(request.ToJsonString())))!;
    }


    [Fact]
    public void CompletionOpensTheGuideOnRerunsAndTheFirstRunOnlyAndNeverFromPrivateBrowsing() {
        Assert.Equal(OnboardingCompletion.OpenGuide, OnboardingCompletionPolicy.Decide(OnboardingEntryPoint.FirstRun, false, false));
        Assert.Equal(OnboardingCompletion.Complete, OnboardingCompletionPolicy.Decide(OnboardingEntryPoint.FirstRun, true, false));
        Assert.Equal(OnboardingCompletion.OpenGuide, OnboardingCompletionPolicy.Decide(OnboardingEntryPoint.Rerun, true, false));
        Assert.Equal(OnboardingCompletion.Complete, OnboardingCompletionPolicy.Decide(OnboardingEntryPoint.ImportBrowser, false, false));
        Assert.Equal(OnboardingCompletion.SourceChanged, OnboardingCompletionPolicy.Decide(OnboardingEntryPoint.Rerun, false, true));
        var wire = Evaluate(new() {
            ["operation"] = "onboarding.completion",
            ["entryPoint"] = "manualSetup",
            ["hasCompletedSetup"] = false,
            ["isPrivateBrowsing"] = false
        });
        Assert.Equal("complete", wire["outcome"]!.GetValue<string>());
        Assert.Equal(ProtocolErrorCodes.InvalidEntryPoint, Assert.Throws<ProtocolException>(() => Evaluate(new() {
            ["operation"] = "onboarding.completion",
            ["entryPoint"] = "later",
            ["hasCompletedSetup"] = false,
            ["isPrivateBrowsing"] = false
        })).Code);
    }

    [Fact]
    public void TheGuideOpensOnlyWhenItsSpaceIsUnchangedFirstAndUnlocked() {
        var target = new OnboardingSpaceIdentity(Guid.NewGuid(), Guid.NewGuid());
        var other = new OnboardingSpaceIdentity(Guid.NewGuid(), Guid.NewGuid());
        var replacedProfile = target with { ProfileId = Guid.NewGuid() };
        Assert.True(OnboardingCompletionPolicy.ConfirmsGuide(new(target, other, other, null, null, target, true, false)));
        Assert.False(OnboardingCompletionPolicy.ConfirmsGuide(new(target, other, target, null, null, target, true, false)));
        Assert.False(OnboardingCompletionPolicy.ConfirmsGuide(new(target, other, other, null, null, null, true, false)));
        Assert.False(OnboardingCompletionPolicy.ConfirmsGuide(new(target, other, other, null, null, target, true, true)));
        Assert.True(OnboardingCompletionPolicy.ConfirmsGuide(new(target, null, target, null, null, null, false, false)));
        Assert.False(OnboardingCompletionPolicy.ConfirmsGuide(new(target, null, replacedProfile, null, null, null, false, false)));
        static JsonObject Identity(OnboardingSpaceIdentity value) => new() {
            ["spaceID"] = value.SpaceId.ToString("D"),
            ["profileID"] = value.ProfileId.ToString("D")
        };
        var wire = Evaluate(new() {
            ["operation"] = "onboarding.guide",
            ["target"] = Identity(target),
            ["originalFirst"] = null,
            ["currentFirst"] = Identity(target),
            ["originalTarget"] = null,
            ["currentTarget"] = null,
            ["previewFirst"] = null,
            ["hasManualPlan"] = false,
            ["locked"] = false
        });
        Assert.True(wire["confirmed"]!.GetValue<bool>());
    }
}
