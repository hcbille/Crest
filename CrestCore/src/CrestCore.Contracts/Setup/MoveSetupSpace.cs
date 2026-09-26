namespace CrestCore.Contracts;

/// Moves the Space `SpaceId` of the manual setup to where `TargetSpaceId`
/// stands, and makes the workspace take the setup's order.
public sealed record MoveSetupSpace(Guid SpaceId, Guid TargetSpaceId) : SetupDraftIntent;
