namespace CrestCore.Contracts;

/// The person answered a site's permission request: whether it `Grants` it,
/// and whether the Space `Remembers` that for the site's later requests, which
/// the core records as the Space's choice in the same step.
public sealed record AnswerPermission(Guid PromptId, bool Grants, bool Remembers) : PromptIntent(PromptId);
