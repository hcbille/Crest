namespace CrestCore.Contracts;

/// Leaves the new Space `SpaceId` out of the manual setup. A setup never
/// removes an existing Space, so naming one changes nothing.
public sealed record RemoveSetupSpace(Guid SpaceId) : SetupDraftIntent;
