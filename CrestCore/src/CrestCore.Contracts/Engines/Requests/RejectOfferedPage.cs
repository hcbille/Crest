namespace CrestCore.Contracts;

/// The page the engine offered as `AdoptionId` has no place in Crest; it closes.
public sealed record RejectOfferedPage(Guid AdoptionId) : PageRequest<bool>;
