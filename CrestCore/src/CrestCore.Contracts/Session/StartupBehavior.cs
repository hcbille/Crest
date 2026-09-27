namespace CrestCore.Contracts;

/// What a new window shows first: the Start Page, or the tab that was active
/// when Crest last quit. The stored preferences spell a behavior as its
/// `Name`, so a name never changes. A behavior travels as its index in `All`,
/// so `All` is append-only.
public sealed class StartupBehavior {
    #region Variables

    public static readonly StartupBehavior ShowStartPage = new(name: "showStartPage", title: "Show Start Page",
        activatesRestoredTab: false);

    public static readonly StartupBehavior LastActiveTab = new(name: "lastActiveTab", title: "Open Last Active Tab",
        activatesRestoredTab: true);

    public static IReadOnlyList<StartupBehavior> All { get; } = [ShowStartPage, LastActiveTab];

    public string Name { get; }

    /// What the General settings call the choice.
    [Localized]
    public string Title { get; }

    /// A window opens on the tab it restores, rather than in front of it.
    public bool ActivatesRestoredTab { get; }

    #endregion

    #region Constructors

    private StartupBehavior(string name, string title, bool activatesRestoredTab) {
        Name = name;
        Title = title;
        ActivatesRestoredTab = activatesRestoredTab;
    }

    #endregion

    #region Actions - Lookup

    public static StartupBehavior? Named(string? name) => All.FirstOrDefault(behavior => behavior.Name == name);

    #endregion
}
