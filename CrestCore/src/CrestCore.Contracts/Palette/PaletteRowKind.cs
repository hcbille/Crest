namespace CrestCore.Contracts;

/// What a palette row does, with the symbol it wears unless the row names its
/// own, the words that say what activating it does, and whether it is the
/// palette's primary action, which Return runs and which shows first and
/// larger. A kind travels as its index in `All`, so `All` is append-only.
public sealed class PaletteRowKind {
    #region Static Variables

    public static readonly PaletteRowKind OpenAddress = new(name: "openAddress", symbol: "globe", action: null, isPrimary: true);
    public static readonly PaletteRowKind Search = new(name: "search", symbol: "magnifyingglass", action: null, isPrimary: true);
    public static readonly PaletteRowKind SearchSuggestion = new(name: "searchSuggestion", symbol: "magnifyingglass",
        action: "Search", isPrimary: false);
    public static readonly PaletteRowKind Tab = new(name: "tab", symbol: "globe", action: "Switch to Tab", isPrimary: false);
    public static readonly PaletteRowKind PinnedTab = new(name: "pinnedTab", symbol: "pin.fill", action: "Switch to Tab",
        isPrimary: false);
    public static readonly PaletteRowKind SavedTab = new(name: "savedTab", symbol: "bookmark", action: "Switch to Tab",
        isPrimary: false);
    public static readonly PaletteRowKind Folder = new(name: "folder", symbol: FolderState.DefaultSymbol, action: "Open First Tab",
        isPrimary: false);
    public static readonly PaletteRowKind Command = new(name: "command", symbol: "command", action: null, isPrimary: false);
    public static readonly PaletteRowKind History = new(name: "history", symbol: "clock", action: "Open", isPrimary: false);

    public static IReadOnlyList<PaletteRowKind> All { get; } =
        [OpenAddress, Search, SearchSuggestion, Tab, PinnedTab, SavedTab, Folder, Command, History];

    #endregion

    #region Variables

    public string Name { get; }

    /// The SF Symbol a row of this kind wears unless it names its own.
    public string Symbol { get; }

    /// What activating the row does, shown at its end, or null for nothing.
    [Localized]
    public string? Action { get; }

    /// The row is the palette's primary action.
    public bool IsPrimary { get; }

    #endregion

    #region Constructors

    private PaletteRowKind(string name, string symbol, string? action, bool isPrimary) {
        Name = name;
        Symbol = symbol;
        Action = action;
        IsPrimary = isPrimary;
    }

    #endregion

    #region Actions - Lookup

    public static PaletteRowKind? Named(string? name) => All.FirstOrDefault(kind => kind.Name == name);

    #endregion
}
