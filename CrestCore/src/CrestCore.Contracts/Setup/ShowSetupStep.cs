namespace CrestCore.Contracts;

/// Shows `Step`: the step Back or Next leads to, or another the person picked.
/// The review needs an import to review; the manual-setup step starts the
/// manual setup, or goes on with the one the device holds.
public sealed record ShowSetupStep(SetupStep Step) : SetupFlowIntent;
