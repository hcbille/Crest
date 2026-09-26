namespace CrestCore.Contracts;

/// Keeps the sync engine's saved state, which it hands the transport to
/// resume from.
public sealed record SaveCloudEngineState(byte[] Serialization) : CloudTransportIntent;
