namespace CrestCore.Contracts;

/// The engine created the page, so its view can be shown.
public sealed record PageViewReady(Guid PageId) : EnginePresentation;
