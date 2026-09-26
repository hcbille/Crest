using CrestCore.Contracts;
using CrestCore.Domain;

using Xunit;

namespace CrestCore.Tests;

/// How many pages memory pressure takes back on each device, in which order,
/// and when iPhone and iPad may reclaim a presented card.
public sealed class PageResidencyPolicyTests {
    public static TheoryData<MemoryPressureLevel, DevicePlatform, int, int> Budgets => new() {
        { MemoryPressureLevel.Warning, DevicePlatform.Desktop, 8, 1 },
        { MemoryPressureLevel.Critical, DevicePlatform.Desktop, 8, 4 },
        { MemoryPressureLevel.Critical, DevicePlatform.Desktop, 7, 4 },
        { MemoryPressureLevel.Critical, DevicePlatform.Desktop, 1, 1 },
        { MemoryPressureLevel.Warning, DevicePlatform.Mobile, 8, 0 },
        { MemoryPressureLevel.Critical, DevicePlatform.Mobile, 8, 1 },
        { MemoryPressureLevel.Critical, DevicePlatform.Desktop, 0, 0 },
        { MemoryPressureLevel.Warning, DevicePlatform.Desktop, 0, 0 },
    };

    [Theory]
    [MemberData(nameof(Budgets))]
    public void MemoryPressureBudgetsDifferByPlatformAndSeverity(MemoryPressureLevel level, DevicePlatform platform, int eligible,
        int limit) =>
        Assert.Equal(limit, PageResidencyPolicy.ReleaseLimit(level, eligible, platform));

    [Fact]
    public void ReleasePlanOrdersOffScreenPagesLeastRecentlyUsedAndExcludesHeldPages() {
        var plan = PageResidencyPolicy.ReleasePlan([
            Candidate("a", 30),
            Candidate("b", 10),
            // Same idle stamp: tab identity decides, so a squeeze repeats.
            Candidate("d", 20),
            Candidate("c", 20),
            // Kept loaded by request, presented on screen, and a tab with no
            // page of its own. The first two are never candidates; the third
            // follows every stamped page.
            Candidate("e", 1, keepsPageLoaded: true),
            Candidate("f", 2, presentedIndex: 0),
            Candidate("10", null),
        ], MemoryPressureLevel.Critical, DevicePlatform.Desktop, focusedIndex: null);
        Assert.Equal(["b", "c", "d", "a", "10"], plan.OffScreen);
        Assert.Empty(plan.PresentedFallback);
    }

    [Fact]
    public void PresentedCardsOnlyFallBackUnderCriticalMobilePressureBeyondTheFocusedNeighbours() {
        (IReadOnlyList<string> OffScreen, IReadOnlyList<string> PresentedFallback) Plan(MemoryPressureLevel level,
            DevicePlatform platform, int focused) => PageResidencyPolicy.ReleasePlan([
                Candidate("101", 40, presentedIndex: 0),
                Candidate("102", 30, presentedIndex: 1),
                Candidate("103", 20, presentedIndex: 2),
                Candidate("104", 10, presentedIndex: 3),
            ], level, platform, focused);
        // Least recently used first, not carousel order.
        Assert.Equal(["104", "103"], Plan(MemoryPressureLevel.Critical, DevicePlatform.Mobile, 0).PresentedFallback);
        Assert.Equal(["104"], Plan(MemoryPressureLevel.Critical, DevicePlatform.Mobile, 1).PresentedFallback);
        Assert.Equal(["101"], Plan(MemoryPressureLevel.Critical, DevicePlatform.Mobile, 2).PresentedFallback);
        Assert.Equal(["102", "101"], Plan(MemoryPressureLevel.Critical, DevicePlatform.Mobile, 3).PresentedFallback);
        Assert.Empty(Plan(MemoryPressureLevel.Warning, DevicePlatform.Mobile, 0).PresentedFallback);
        Assert.Empty(Plan(MemoryPressureLevel.Critical, DevicePlatform.Desktop, 0).PresentedFallback);
        Assert.Empty(Plan(MemoryPressureLevel.Critical, DevicePlatform.Mobile, 0).OffScreen);
    }

    [Fact]
    public void ReleasePlanRejectsInconsistentPresentationAndRepeatedTabs() {
        Assert.Throws<BrowserRuleException>(() => PageResidencyPolicy.ReleasePlan(
            [Candidate("201", 1), Candidate("201", 2)], MemoryPressureLevel.Critical, DevicePlatform.Mobile, focusedIndex: null));
        Assert.Throws<BrowserRuleException>(() => PageResidencyPolicy.ReleasePlan(
            [new ResidencyCandidate("202", 1, KeepsPageLoaded: false, IsPresented: true, PresentedIndex: null)],
            MemoryPressureLevel.Critical, DevicePlatform.Mobile, focusedIndex: 0));
    }

    private static ResidencyCandidate Candidate(string tabId, double? inactiveSince, bool keepsPageLoaded = false,
        int? presentedIndex = null) =>
        new(tabId, inactiveSince, keepsPageLoaded, presentedIndex.HasValue, presentedIndex);
}
