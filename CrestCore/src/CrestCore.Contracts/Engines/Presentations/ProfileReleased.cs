namespace CrestCore.Contracts;

/// The engine let go of the profile `ProfileId` names: its pages and windows
/// closed and its extensions are gone.
public sealed record ProfileReleased(Guid ProfileId) : EnginePresentation;
