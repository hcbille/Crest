namespace CrestCore.Contracts;

/// The name, symbol, accent and look an imported or drafted Space takes. A
/// blank name reads as `UntitledName` and a blank symbol as the default one;
/// the look is kept within the ranges every device draws.
public sealed record SpaceCustomization(string Name, string Symbol, SpaceAccent Accent, SpaceBranding Branding) {
    #region Static Variables

    /// What a Space named with nothing but blanks is called.
    public const string UntitledName = "Untitled Space";

    #endregion

    #region Actions - Names

    /// The name `name` gives a Space: trimmed, or `UntitledName` when blank.
    public static string Resolved(string name) => string.IsNullOrWhiteSpace(name) ? UntitledName : name.Trim();

    #endregion
}
