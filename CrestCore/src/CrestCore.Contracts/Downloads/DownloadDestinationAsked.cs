namespace CrestCore.Contracts;

/// Where the file of the download `DownloadId` goes waits on the platform: the
/// download folder of the Space `SpaceId`, or the person's choice when
/// `ForcesPrompt` asks for one or that Space asks every time.
public sealed record DownloadDestinationAsked(Guid PromptId, Guid DownloadId, Guid SpaceId, string SuggestedFilename,
    bool ForcesPrompt) : Change;
