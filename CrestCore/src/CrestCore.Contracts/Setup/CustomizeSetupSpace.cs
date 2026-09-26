namespace CrestCore.Contracts;

/// Gives the Space `SpaceId` of the manual setup the name and look of
/// `Customization`. The look is kept within the ranges every device draws;
/// the name is kept as typed.
public sealed record CustomizeSetupSpace(Guid SpaceId, SpaceCustomization Customization) : SetupDraftIntent;
