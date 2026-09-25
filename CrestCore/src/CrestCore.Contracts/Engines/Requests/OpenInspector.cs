namespace CrestCore.Contracts;

/// Opens the engine's inspector on the page, docked in the page's own card, on
/// `Panel` when the engine can choose where it starts.
public sealed record OpenInspector(Guid PageId, InspectorPanel? Panel) : PageRequest<bool>;
