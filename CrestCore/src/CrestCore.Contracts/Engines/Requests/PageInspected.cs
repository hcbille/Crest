namespace CrestCore.Contracts;

/// Whether an inspector is open on the page, docked or in a window of its own.
public sealed record PageInspected(Guid PageId) : PageRequest<bool>;
