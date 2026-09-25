namespace CrestCore.Contracts;

/// The engine closed the page on its own, as a script's `window.close()` does.
public sealed record PageViewClosed(Guid PageId) : EnginePresentation;
