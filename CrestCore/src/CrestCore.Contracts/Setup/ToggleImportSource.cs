namespace CrestCore.Contracts;

/// Chooses `Source` to import from, or leaves it out when chosen. Any review
/// or failure goes, and setup shows the browsers again.
public sealed record ToggleImportSource(ImportSource Source) : SetupFlowIntent;
