namespace CrestCore.Contracts;

/// The process that drew the page stopped, so the page shows nothing until it
/// loads again.
public sealed record PageRendererGone(Guid PageId) : EnginePresentation;
