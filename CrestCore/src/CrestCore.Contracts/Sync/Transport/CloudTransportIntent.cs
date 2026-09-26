namespace CrestCore.Contracts;

/// An intent from the cloud transport about its own state on this device:
/// the engine's saved cursor, the last server fields of each record it
/// uploads over, whether a download must be recovered with a full pull,
/// whether an account change waits for the person's decision, and whether
/// this device's copy overwrites the cloud's. The device store keeps it
/// beside the session and never syncs it.
///
/// The transport sends one from its own thread, never the host's; the core
/// takes no lock the host's intents wait for. Each is on disk before it
/// returns, and a save that fails is `SaveFailed` and changes nothing. Its
/// answer carries `CloudTransportChanged` with the state it left, which
/// never reaches the host's state.
public abstract record CloudTransportIntent : Intent;
