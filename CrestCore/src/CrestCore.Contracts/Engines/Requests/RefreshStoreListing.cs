namespace CrestCore.Contracts;

/// The Chrome Web Store listing the page shows restates its install button
/// from the engine's own registry: the review its request began finished, or
/// never started.
public sealed record RefreshStoreListing(Guid PageId) : PageRequest<bool>;
