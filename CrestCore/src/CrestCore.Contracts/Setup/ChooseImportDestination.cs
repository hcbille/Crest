namespace CrestCore.Contracts;

/// Makes the reviewed Space `SourceSpaceId` join the existing Space
/// `DestinationSpaceId`, taking that Space's name and look, or come in as a new
/// Space with its own when null.
public sealed record ChooseImportDestination(Guid SourceSpaceId, Guid? DestinationSpaceId) : SetupFlowIntent;
