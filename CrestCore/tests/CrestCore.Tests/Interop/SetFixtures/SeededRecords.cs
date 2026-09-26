using CrestCore.Contracts;

namespace CrestCore.Tests.Seeded;

// A contract record another record holds lives in the contracts assembly, so
// these fixtures hold the core's archived tab, whose tab has resolved values.

/// A message the platform sends that holds a record the core resolves values of.
public sealed record KeepTab(ArchivedTabState Archived) : Intent;

/// The same record as a change the core writes, which no platform builds.
public sealed record TabKept(ArchivedTabState Archived) : Change;

/// A message the platform sends that claims a value only the core resolves.
public sealed record Resolving(double Level) : Intent {
    #region Variables

    [Resolved]
    public double Share => Level / 2;

    #endregion
}
