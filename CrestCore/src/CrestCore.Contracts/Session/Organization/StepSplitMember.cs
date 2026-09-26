namespace CrestCore.Contracts;

/// Moves a tab `Offset` members along its split. Refused with `NoSplitStep`
/// when the step would move nothing: no offset, a step past either end, or a
/// tab in no split.
public sealed record StepSplitMember(Guid WorkspaceId, Guid SpaceId, Guid TabId, int Offset) : SessionIntent(WorkspaceId);
