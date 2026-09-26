namespace CrestCore.Contracts;

/// Shows the reviewed Space `SourceSpaceId`.
public sealed record ShowImportSpace(Guid SourceSpaceId) : SetupFlowIntent;
