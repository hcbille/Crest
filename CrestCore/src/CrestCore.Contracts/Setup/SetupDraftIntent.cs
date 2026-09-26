namespace CrestCore.Contracts;

/// Starts, edits or ends the manual setup this device holds. Each publishes
/// the setup as it leaves it in `SetupDraftChanged`. An edit is refused with
/// `NoManualSetup` while no setup is in progress.
public abstract record SetupDraftIntent : Intent;
