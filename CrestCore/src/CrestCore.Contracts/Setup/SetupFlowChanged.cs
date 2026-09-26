namespace CrestCore.Contracts;

/// Setup on this device changed, or ended when `Flow` is null.
public sealed record SetupFlowChanged(SetupFlowState? Flow) : Change;
