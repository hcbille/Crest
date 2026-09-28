namespace CrestCore.Contracts;

/// A browsing engine Crest can host pages on. A composition registers the
/// engines it carries, one of them as the default, and each page belongs to
/// one engine. A kind travels as its index in `All`, so `All` is append-only.
public sealed class EngineKind {
    #region Static Variables

    public static readonly EngineKind Chromium = new(name: "chromium", title: "Chromium", symbol: "smallcircle.filled.circle",
        pageDescription: "Runs in Chromium");
    public static readonly EngineKind WebKit = new(name: "webkit", title: "WebKit", symbol: "location.north.fill",
        pageDescription: "Runs in WebKit");

    public static IReadOnlyList<EngineKind> All { get; } = [Chromium, WebKit];

    #endregion

    #region Variables

    public string Name { get; }

    /// The engine's name as the person reads it, where Crest says which
    /// engine hosts a page.
    [Localized]
    public string Title { get; }

    public string TitleComment { get; } = "The name of a browser engine. Keep the product name as it is.";

    /// The SF Symbol that stands for the engine beside its name and on the
    /// badge a tab's icon wears while its page runs on it. A stand-in, never
    /// the engine's own logo: the engines' logos are their owners' trademarks,
    /// and Apple's `safari` symbol may only refer to Safari.
    public string Symbol { get; }

    /// What a tab says about the engine its page runs on to someone who
    /// cannot see its badge, and what the badge says on hover.
    [Localized]
    public string PageDescription { get; }

    public string PageDescriptionComment { get; } =
        "Said of a tab whose page runs in this browser engine rather than the default one. Keep the product name as it is.";

    #endregion

    #region Constructors

    private EngineKind(string name, string title, string symbol, string pageDescription) {
        Name = name;
        Title = title;
        Symbol = symbol;
        PageDescription = pageDescription;
    }

    #endregion

    #region Actions - Lookup

    public static EngineKind? Named(string? name) => All.FirstOrDefault(kind => kind.Name == name);

    #endregion
}
