namespace CrestCore.Contracts;

/// Stops reading the current browser and goes back to choosing browsers.
public sealed record CancelImportRead() : SetupFlowIntent;
