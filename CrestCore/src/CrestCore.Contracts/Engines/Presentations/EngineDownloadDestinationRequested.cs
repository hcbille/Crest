namespace CrestCore.Contracts;

/// Where a download's file goes, asked before it begins: `SuggestedFilename`
/// is the engine's name for it, and `ForcesPrompt` asks the person to choose.
/// The download waits for `AnswerEngineDownloadDestination`.
public sealed record EngineDownloadDestinationRequested(Guid RequestId, EngineDownload Download,
    string SuggestedFilename, bool ForcesPrompt) : EnginePresentation;
