namespace CrestCore.Contracts;

/// Runs `Source` once in Crest's isolated world of the frame `FrameId` names,
/// in the document it shows now, and presents `ContentScriptEvaluated` with
/// `EvaluationId`. False when the frame is gone.
public sealed record EvaluateContentScript(Guid PageId, Guid EvaluationId, string Source, string FrameId)
    : PageRequest<bool>;
