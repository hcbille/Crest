namespace CrestCore.Contracts;

/// Carries whether an installed release completed setup, as it kept it under
/// `crest.onboarding.completed`, into the device store once, and publishes
/// whether this device has completed setup. A device that keeps no file keeps
/// `Completed` for this run; one that adopted it before keeps what it has.
public sealed record AdoptSetupCompletion(bool Completed) : SetupFlowIntent;
