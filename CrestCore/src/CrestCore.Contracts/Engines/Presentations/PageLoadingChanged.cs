namespace CrestCore.Contracts;

/// The page started or stopped loading.
public sealed record PageLoadingChanged(Guid PageId, bool IsLoading) : EnginePresentation;
