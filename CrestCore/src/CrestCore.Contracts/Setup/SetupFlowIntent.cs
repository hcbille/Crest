namespace CrestCore.Contracts;

/// Moves setup on this device along. Each publishes setup as it leaves it in
/// `SetupFlowChanged`. One is refused with `NoSetup` while setup is not open,
/// and one that changes what setup works on with `SetupBusy` while it reads or
/// imports.
public abstract record SetupFlowIntent : Intent;
