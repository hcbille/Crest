namespace CrestCore.Contracts;

/// Whether this build holds the entitlement for Crest's container.
public sealed record CloudEntitlementChecked(long Attempt, bool Granted) : CloudSyncControlIntent;
