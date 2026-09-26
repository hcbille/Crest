namespace CrestCore.Contracts;

/// The page the engine offered as `AdoptionId` becomes the page `PageId`
/// names, which the core is opening, instead of a new one. False when the
/// offer is gone.
public sealed record AdoptOfferedPage(Guid PageId, Guid AdoptionId) : PageRequest<bool>;
