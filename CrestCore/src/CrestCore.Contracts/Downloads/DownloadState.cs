namespace CrestCore.Contracts;

/// One download record owned by a browsing profile. `Failure` says why a
/// failed record stopped, when that is known; `Message` explains a canceled or
/// failed record in words its engine or platform gave. Both are null in every
/// other phase.
public sealed record DownloadState(Guid Id, Guid ProfileId, DateTimeOffset CreatedAt, string Filename, string? Destination,
    double Progress, DownloadTelemetry Telemetry, DownloadPhase Phase, DownloadFailure? Failure, string? Message,
    DownloadRiskAssessment? Risk, bool IsAcknowledged);
