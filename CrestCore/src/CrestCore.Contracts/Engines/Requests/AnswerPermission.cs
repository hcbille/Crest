namespace CrestCore.Contracts;

/// Crest's answer to the request `PermissionRequested` presented.
/// TRANSITIONAL until permission prompts move to the core (WP C (f)).
public sealed record AnswerPermission(Guid PageId, Guid RequestId, PermissionAnswer Answer) : PageRequest<bool>;
