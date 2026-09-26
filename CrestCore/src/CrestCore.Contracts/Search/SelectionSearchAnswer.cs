namespace CrestCore.Contracts;

/// The results address of a selection search, or null when the selection is
/// blank or the address is one Crest does not open, and the title of the
/// engine that runs it.
public sealed record SelectionSearchAnswer(string? Url, string EngineTitle);
