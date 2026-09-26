namespace CrestCore.Contracts;

/// A download the engine runs for one of Crest's profiles, as Crest shows it:
/// the page it came from, its file and progress, and a warning the person may
/// override with `ApprovalToken`. TRANSITIONAL until downloads move to the
/// core (WP C (f)).
public sealed record EngineDownload(string DownloadId, Guid ProfileId, Guid? SourcePageId, string Filename, string? Path,
    long Received, long Total, DateTimeOffset StartedAt, bool Restored, bool Paused, EngineDownloadState State,
    EngineDownloadWarning? Warning, string? Failure, string ApprovalToken);
