namespace CrestCore.Contracts;

/// A document in a page asked for a permission Crest records, which waits for
/// the core's `SettlePermission`. The core answers from the Space's choices
/// when they hold one, and asks the person only when they do not.
public sealed record PermissionRequested(Guid PromptId, Guid PageId, PermissionQuestion Question) : EngineEvent;
