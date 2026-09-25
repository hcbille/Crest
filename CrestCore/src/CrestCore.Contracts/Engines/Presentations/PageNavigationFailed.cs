namespace CrestCore.Contracts;

/// The page's navigation failed; the engine shows its own error page.
public sealed record PageNavigationFailed(Guid PageId) : EnginePresentation;
