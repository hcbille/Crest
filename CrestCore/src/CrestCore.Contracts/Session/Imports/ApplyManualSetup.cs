namespace CrestCore.Contracts;

/// Applies the manual setup this device holds for the workspace: each new
/// Space of the setup joins with its identity, profile, name and look, and
/// each existing Space takes the name and look the setup gave it. When the
/// setup's order was edited, the Spaces take it, followed by any Space the
/// setup does not name. A first launch's Spaces stop being disposable. The
/// setup ends once it is applied.
///
/// Refused with `NoManualSetup` when no setup is in progress for the
/// workspace, `SpaceProfileChanged` when an existing Space no longer uses the
/// setup's profile, and `SpaceAlreadyExists` or `ProfileInUse` when a new
/// Space takes an identity or profile another Space holds.
public sealed record ApplyManualSetup(Guid WorkspaceId, Guid WindowId) : ImportWorkspace(WorkspaceId, WindowId);
