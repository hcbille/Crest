namespace CrestCore.Contracts;

/// Marks a fixed set's string member as user-facing English text. The
/// generator gives Swift a `LocalizedStringResource` built from the literal, so
/// Xcode extracts it into the string catalog. A string member named after it
/// with `Comment` appended, such as `TitleComment` for `Title`, is the note for
/// translators and reaches Swift only as the resource's comment.
[AttributeUsage(AttributeTargets.Property)]
public sealed class LocalizedAttribute : Attribute {
    #region Variables

    /// An int member of the same set whose value the text carries. Where the
    /// member has a value, the text spells it `%lld` exactly once, and Swift
    /// interpolates the value there, so every member shares the one catalog
    /// key: `Select Tab %lld` reaches Swift as "Select Tab \(3)".
    public string? Argument { get; set; }

    /// The text is a format that spells `%lld` exactly once for a number the
    /// core supplies when it writes the text into data, such as a Space's
    /// ordinal. Swift receives the format whole, localizes it and hands it back
    /// to the core, so the catalog key keeps its `%lld`.
    public bool IsFormat { get; set; }

    #endregion
}
