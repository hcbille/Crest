namespace CrestCore.Contracts;

/// What `EvaluateContentScript` answered, as JSON, or nothing when its
/// document went away first.
public sealed record ContentScriptEvaluated(Guid PageId, Guid EvaluationId, string? Json) : EnginePresentation;
