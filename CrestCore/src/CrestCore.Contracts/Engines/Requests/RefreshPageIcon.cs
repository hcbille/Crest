namespace CrestCore.Contracts;

/// Fetches the page's icon again rather than keep the one the engine has.
public sealed record RefreshPageIcon(Guid PageId) : PageRequest<bool>;
