namespace CrestCore.Contracts;

/// What an engine needs to bring a page back as it was: its history, opaque to
/// the core, at `Url`, the address it showed. The core keeps it in memory
/// only, never in a saved or synced file.
public sealed record PageRestoreState(string Url, byte[] State);
