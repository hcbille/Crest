namespace CrestCore.Contracts;

/// Brings the saved passwords that belong with the reviewed Space
/// `SourceSpaceId`, or leaves them out.
public sealed record IncludeImportPasswords(Guid SourceSpaceId, bool Included) : SetupFlowIntent;
