namespace CrestCore.Contracts;

/// The inspector on the page is going away, whichever way it was closed.
public sealed record InspectorClosed(Guid PageId) : EnginePresentation;
