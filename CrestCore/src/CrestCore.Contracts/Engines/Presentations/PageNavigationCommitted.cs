namespace CrestCore.Contracts;

/// The page now shows the document at `Url`, a new one or a move within the
/// same one, and is still loading it when `IsLoading`.
public sealed record PageNavigationCommitted(Guid PageId, string Url, bool IsLoading) : EnginePresentation;
