namespace CrestCore.Contracts;

/// Whether this device has completed setup changed, or was read as the
/// device store adopted it.
public sealed record SetupCompletedChanged(bool Completed) : Change;
