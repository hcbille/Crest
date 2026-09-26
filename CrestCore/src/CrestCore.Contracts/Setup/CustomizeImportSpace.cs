namespace CrestCore.Contracts;

/// Gives the reviewed Space `SourceSpaceId` the name and look of
/// `Customization`, kept within the ranges every device draws.
public sealed record CustomizeImportSpace(Guid SourceSpaceId, SpaceCustomization Customization) : SetupFlowIntent;
