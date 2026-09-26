namespace CrestCore.Contracts;

/// Why setup could not go on, the browser it concerns, and the words of what
/// refused it, when something did.
public sealed record SetupFailure(SetupFailureReason Reason, ImportSource? Source, string? Detail);
