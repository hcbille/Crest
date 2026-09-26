namespace CrestCore.Contracts;

/// Deletes the engine profile `ProfileId` names and every private profile
/// derived from it: their pages and windows close at once, presenting
/// `ProfileReleased`, then the regular profile's data is wiped and its
/// directory left for deletion, presenting `ProfileDeleted` with `DeletionId`.
/// An `Ephemeral` profile is a private one with nothing on disk. False when
/// the profile cannot be deleted now.
public sealed record DeleteProfile(Guid ProfileId, bool Ephemeral, Guid DeletionId) : PageRequest<bool>;
