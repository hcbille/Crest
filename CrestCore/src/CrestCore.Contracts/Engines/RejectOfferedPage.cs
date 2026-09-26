namespace CrestCore.Contracts;

/// The page the engine offered as `OfferId` has no place in Crest, so the
/// engine closes it.
public sealed record RejectOfferedPage(Guid OfferId) : EngineCommand;
