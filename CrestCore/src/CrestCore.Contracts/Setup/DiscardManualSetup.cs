namespace CrestCore.Contracts;

/// Ends the manual setup this device holds without applying it, and forgets
/// the one it kept for a later launch.
public sealed record DiscardManualSetup() : SetupDraftIntent;
