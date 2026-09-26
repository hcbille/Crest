namespace CrestCore.Contracts;

/// A download the engine runs for one of Crest's profiles: the page it came
/// from, its file and progress, and a warning the person may override while it
/// is still the one `ApprovalToken` names. A failed download says what
/// interrupted it, and `FailureDetail` is the engine's own description of
/// that. `DownloadId` is the engine's own name for it within its profile.
public sealed record EngineDownload(string DownloadId, Guid ProfileId, Guid? SourcePageId, string Filename, string? Path,
    long Received, long Total, DateTimeOffset StartedAt, bool Restored, bool Paused, EngineDownloadState State,
    EngineDownloadWarning? Warning, EngineDownloadInterruption? Interruption, string? FailureDetail, string ApprovalToken);
