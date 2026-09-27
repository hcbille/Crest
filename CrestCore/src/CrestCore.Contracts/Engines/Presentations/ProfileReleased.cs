namespace CrestCore.Contracts;

/// The engine let go of the profile `ProfileId` names, and of each private
/// profile in `DerivedProfileIds` that was derived from it: their pages and
/// windows closed and their extensions are gone.
public sealed record ProfileReleased(Guid ProfileId, IReadOnlyList<Guid> DerivedProfileIds) : EnginePresentation;
