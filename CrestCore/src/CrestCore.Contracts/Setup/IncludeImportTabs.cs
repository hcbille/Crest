namespace CrestCore.Contracts;

/// Brings the tabs `TabIds` of the reviewed Space `SourceSpaceId`, or leaves
/// them out. Bringing a tab brings its Space.
public sealed record IncludeImportTabs(Guid SourceSpaceId, IReadOnlyList<Guid> TabIds, bool Included) : SetupFlowIntent;
