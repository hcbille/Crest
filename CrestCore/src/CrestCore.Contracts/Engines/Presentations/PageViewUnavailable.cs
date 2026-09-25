namespace CrestCore.Contracts;

/// The engine could not create the page, so it has no view to show.
public sealed record PageViewUnavailable(Guid PageId) : EnginePresentation;
