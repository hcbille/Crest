namespace CrestCore.Contracts;

/// A Space's deletion cannot finish before this run erased its profile's data
/// on every registered engine.
public sealed record SpaceDataNotErased(Guid SpaceId) : Rejection;
