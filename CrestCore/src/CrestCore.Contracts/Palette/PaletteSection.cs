namespace CrestCore.Contracts;

/// A group of the palette's rows: the address or search to run, which has no
/// header, and then each kind of thing the palette ranks, under its title. `Limit` caps the
/// rows the section shows; `RestingLimit` caps them before anything is typed.
/// A section travels as its index in `All`, so `All` is append-only.
public sealed class PaletteSection {
    #region Static Variables

    public static readonly PaletteSection Intent = new(name: "intent", title: null, limit: 1, restingLimit: 0);
    public static readonly PaletteSection SearchSuggestions = new(name: "searchSuggestions", title: "Search Suggestions", limit: 3,
        restingLimit: 0);
    public static readonly PaletteSection OpenTabs = new(name: "openTabs", title: "Open Tabs", limit: 0,
        restingLimit: 5);
    public static readonly PaletteSection Tabs = new(name: "tabs", title: "Tabs", limit: 8, restingLimit: 0);
    public static readonly PaletteSection Actions = new(name: "actions", title: "Actions", limit: 5,
        restingLimit: 3);
    public static readonly PaletteSection Saved = new(name: "saved", title: "Pinned & Saved", limit: 5,
        restingLimit: 0);
    public static readonly PaletteSection History = new(name: "history", title: "History", limit: 6,
        restingLimit: 0);

    /// The sections, in the order the palette shows them.
    public static IReadOnlyList<PaletteSection> All { get; } = [Intent, SearchSuggestions, OpenTabs, Tabs, Actions, Saved, History];

    #endregion

    #region Variables

    public string Name { get; }

    /// The header the palette shows above the section's rows, or null for none.
    [Localized]
    public string? Title { get; }

    /// The most rows the section shows for typed text.
    public int Limit { get; }

    /// The most rows the section shows before anything is typed.
    public int RestingLimit { get; }

    #endregion

    #region Constructors

    private PaletteSection(string name, string? title, int limit, int restingLimit) {
        Name = name;
        Title = title;
        Limit = limit;
        RestingLimit = restingLimit;
    }

    #endregion

    #region Actions - Lookup

    public static PaletteSection? Named(string? name) => All.FirstOrDefault(section => section.Name == name);

    /// How many rows the section shows: `RestingLimit` before anything is
    /// typed, `Limit` after.
    public int Shows(bool resting) => resting ? RestingLimit : Limit;

    #endregion
}
