namespace CrestCore.Contracts;

/// Closes the inspector on the page, docked or in a window of its own.
public sealed record CloseInspector(Guid PageId) : PageRequest<bool>;
