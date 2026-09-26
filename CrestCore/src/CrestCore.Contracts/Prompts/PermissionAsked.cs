namespace CrestCore.Contracts;

/// A site's permission request that its Space's choices do not answer waits
/// on the person.
public sealed record PermissionAsked(Guid PromptId, Guid PageId, PermissionQuestion Question) : Change;
