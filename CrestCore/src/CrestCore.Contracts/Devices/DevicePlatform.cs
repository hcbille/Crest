namespace CrestCore.Contracts;

/// The device class a rule answers for: desktop is the Mac, mobile is iPhone
/// and iPad. A platform carries every budget that differs by device, so a rule
/// asks the platform rather than naming one.
///
/// JSON policy requests spell a platform as its `Name`.
public sealed class DevicePlatform {
    #region Variables

    /// The Mac gives back one page under warning pressure and half of the
    /// eligible pages, at least one, under critical pressure. A page on screen
    /// is never taken. A manual setup left unfinished starts over at the next
    /// launch, and setup imports from the browsers installed on it.
    public static readonly DevicePlatform Desktop = new(name: "desktop", warningReleaseLimit: _ => 1,
        criticalReleaseLimit: eligible => Math.Max(1, (eligible + 1) / 2), reclaimsPresentedPagesAt: null, keepsSetupDraft: false,
        importsBrowsers: true);

    /// iPhone and iPad hold on under warning pressure and give back one page
    /// under critical pressure. Critical pressure may also take a carousel card
    /// away from the focused one when nothing off screen could go. An
    /// unfinished manual setup waits for the next launch, since the system may
    /// end the app while it is in the background.
    public static readonly DevicePlatform Mobile = new(name: "mobile", warningReleaseLimit: _ => 0,
        criticalReleaseLimit: _ => 1, reclaimsPresentedPagesAt: MemoryPressureLevel.Critical, keepsSetupDraft: true,
        importsBrowsers: false);

    public static IReadOnlyList<DevicePlatform> All { get; } = [Desktop, Mobile];

    public string Name { get; }

    /// Whether the device store keeps an unfinished manual setup for the next
    /// launch.
    public bool KeepsSetupDraft { get; }

    /// Whether setup offers to import from other browsers installed here.
    /// Where it does not, setup goes from the welcome to setting up Spaces by
    /// hand.
    public bool ImportsBrowsers { get; }

    /// The most pages pressure at each level may take back, from the number of
    /// eligible pages.
    private readonly IReadOnlyDictionary<MemoryPressureLevel, Func<int, int>> releaseLimits;

    /// The level at which pressure may reclaim presented cards, or null when a
    /// page on screen is never taken.
    private readonly MemoryPressureLevel? reclaimsPresentedPagesAt;

    #endregion

    #region Constructors

    private DevicePlatform(string name, Func<int, int> warningReleaseLimit, Func<int, int> criticalReleaseLimit,
        MemoryPressureLevel? reclaimsPresentedPagesAt, bool keepsSetupDraft, bool importsBrowsers) {
        Name = name;
        KeepsSetupDraft = keepsSetupDraft;
        ImportsBrowsers = importsBrowsers;
        releaseLimits = new Dictionary<MemoryPressureLevel, Func<int, int>> {
            [MemoryPressureLevel.Warning] = warningReleaseLimit,
            [MemoryPressureLevel.Critical] = criticalReleaseLimit
        };
        this.reclaimsPresentedPagesAt = reclaimsPresentedPagesAt;
    }

    #endregion

    #region Actions - Lookup

    public static DevicePlatform? Named(string? name) => All.FirstOrDefault(platform => platform.Name == name);

    #endregion

    #region Actions - Memory pressure

    /// How many of `eligiblePageCount` pages pressure at `level` may take back.
    public int ReleaseLimit(MemoryPressureLevel level, int eligiblePageCount) => releaseLimits[level](eligiblePageCount);

    /// Whether pressure at `level` may take presented cards that sit away from
    /// the focused one.
    public bool ReclaimsPresentedPages(MemoryPressureLevel level) => reclaimsPresentedPagesAt == level;

    #endregion
}
