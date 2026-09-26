namespace CrestCore.Contracts;

/// The palette's rows, in the groups it shows them, first to last. The first
/// row is what Return activates. `Completion` completes the text as an address
/// the Space already knows, or is null. `SuggestionAddress` is where the
/// platform may fetch search suggestions for the text, or null when the window
/// is private, the Space does not offer them, or its search engine has none.
public sealed record PaletteAnswer(IReadOnlyList<PaletteGroup> Groups, AddressCompletion? Completion, string? SuggestionAddress);
