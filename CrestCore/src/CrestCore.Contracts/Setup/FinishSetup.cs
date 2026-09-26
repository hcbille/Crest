namespace CrestCore.Contracts;

/// Finishes setup from the window `WindowId`: applies the manual setup when
/// the person set Spaces up by hand, marks setup done on this device, and
/// publishes `SetupFinished` with the Space the Getting Started guide opens
/// in when the entry opens it.
///
/// Refused with `PersistentWorkspaceRequired` from a workspace setup cannot
/// change, `GuideSpaceLocked` while the Space the guide would open in is
/// locked, which the platform unlocks before finishing again, and whatever
/// refuses the manual setup.
public sealed record FinishSetup(Guid WindowId) : SetupFlowIntent;
