namespace CrestCore.Contracts;

/// Runs `Action` in the page's media session while it is still `Document`'s.
public sealed record PerformMediaAction(Guid PageId, string Document, MediaSessionAction Action) : PageRequest<bool>;
