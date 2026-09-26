namespace CrestCore.Contracts;

/// Where a download's file goes, asked before it begins: `SuggestedFilename`
/// is the engine's name for it, and `ForcesPrompt` asks the person to choose.
/// The download waits for the core's `SettleDownloadDestination`, which first
/// judges its risk from the platform's `Facts` and whether the person started
/// it: a download the person must confirm is asked about before its place.
/// `SourceHost` is the host the file came from, which that question shows; the
/// engine never sends the address itself.
public sealed record EngineDownloadDestinationRequested(Guid PromptId, EngineDownload Download, string SuggestedFilename,
    bool ForcesPrompt, DownloadRiskFacts Facts, bool UserInitiated, string? SourceHost) : EngineEvent;
