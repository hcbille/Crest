namespace CrestCore.Contracts;

/// The docked inspector on the page appeared, moved to another side, changed
/// size or went away, so the page's card lays out again.
public sealed record InspectorLayoutChanged(Guid PageId) : EnginePresentation;
