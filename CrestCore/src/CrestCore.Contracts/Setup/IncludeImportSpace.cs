namespace CrestCore.Contracts;

/// Brings the reviewed Space `SourceSpaceId` with every tab its destination
/// does not already hold, or leaves it out with all of them.
public sealed record IncludeImportSpace(Guid SourceSpaceId, bool Included) : SetupFlowIntent;
