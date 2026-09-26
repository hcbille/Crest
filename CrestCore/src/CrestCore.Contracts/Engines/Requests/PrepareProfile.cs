namespace CrestCore.Contracts;

/// Loads the engine profile of the Space profile `ProfileId` names, so its
/// extensions can be listed before anything opens in it, and presents
/// `ProfilePrepared` with `PreparationId`. False when it cannot start.
public sealed record PrepareProfile(Guid ProfileId, Guid PreparationId) : PageRequest<bool>;
