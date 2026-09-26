namespace CrestCore.Contracts;

/// The cloud's zone of Crest's records is gone, as `Loss` says: every
/// record's server fields go with it, and so does the engine's saved state
/// unless the loss restores the zone from this device's records.
public sealed record ForgetCloudZone(CloudZoneLoss Loss) : CloudTransportIntent;
