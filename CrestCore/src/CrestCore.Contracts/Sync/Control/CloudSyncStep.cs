namespace CrestCore.Contracts;

/// One step the platform takes for iCloud sync, for the start or sync
/// `Attempt` names. `UsesCloud` tells `ApplyChosenCopy` which copy the person
/// chose.
public sealed record CloudSyncStep(CloudSyncStepKind Kind, long Attempt, bool UsesCloud);
