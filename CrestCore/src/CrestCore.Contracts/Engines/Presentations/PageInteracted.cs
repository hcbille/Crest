namespace CrestCore.Contracts;

/// The person typed, clicked or scrolled in the page. Presented at most once a
/// second, for timers that close pages left idle.
public sealed record PageInteracted(Guid PageId) : EnginePresentation;
