namespace CrestCore.Contracts;

/// Starts a manual setup of the workspace's Spaces, or goes on with the one
/// this device holds for it, following Spaces changed meanwhile. A platform
/// that keeps an unfinished setup goes on with the one it kept at an earlier
/// launch. `StartsOver` discards any setup first. A setup of no Spaces starts
/// with a new one.
///
/// Refused with `PersistentWorkspaceRequired` for a workspace whose Spaces a
/// setup cannot change, as `ApplyManualSetup` is.
public sealed record BeginManualSetup(Guid WorkspaceId, bool StartsOver) : SetupDraftIntent;
