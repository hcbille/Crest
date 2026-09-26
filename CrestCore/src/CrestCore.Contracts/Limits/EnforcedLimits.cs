namespace CrestCore.Contracts;

/// The capacities the core enforces. Native surfaces read them to shape what
/// they offer, such as a pin action or a nested folder; the core still refuses
/// anything past them.
public sealed record EnforcedLimits() : Query<CapacityLimits>;
