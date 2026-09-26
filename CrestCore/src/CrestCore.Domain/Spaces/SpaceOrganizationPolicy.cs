using CrestCore.Contracts;

namespace CrestCore.Domain;

/// Shared rules for Space commands, independent of native models and storage.
public static class SpaceOrganizationPolicy {
    #region Static Variables

    /// The symbol a Space given a blank one wears.
    private const string DefaultSymbol = "square.grid.2x2";

    #endregion

    #region Actions - Space organization

    /// Throws `Rejected` with `CannotDeleteLastSpace` unless `count` Spaces
    /// leave one behind when one goes.
    public static void RequireRemovable(int count) {
        if (count <= 1) throw new Rejected(new CannotDeleteLastSpace());
    }

    #endregion

    #region Mutators

    public static string Name(string value) => SpaceCustomization.Resolved(value);

    /// The name a person gave a Space, trimmed, as `Name` reads it. Throws
    /// `Rejected` with `InvalidName` for one longer than a Space name holds.
    public static string ChosenName(string value) {
        var name = Name(value);
        if (name.Length > BrowserSpace.MaximumNameLength) throw new Rejected(new InvalidName(BrowserSpace.MaximumNameLength));
        return name;
    }

    public static string Symbol(string value) => string.IsNullOrWhiteSpace(value) ? DefaultSymbol : value.Trim();

    #endregion
}
