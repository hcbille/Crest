namespace CrestCore.Contracts;

/// A live or blocked download failed, for `Reason` when it is known, with the
/// engine's or platform's own `Message` when it has one; one of the two is
/// given. A blocked automatic download fails when its retry can no longer be
/// replayed.
public sealed record FailDownload(Guid DownloadId, DownloadFailure? Reason, string? Message) : DownloadIntent;
