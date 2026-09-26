namespace CrestCore.Contracts;

/// An engine registered or went away. `Roster` holds every engine registered
/// now.
public sealed record EnginesChanged(EngineRoster Roster) : Change;
