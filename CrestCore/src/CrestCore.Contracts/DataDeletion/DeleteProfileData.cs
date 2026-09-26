namespace CrestCore.Contracts;

/// Erases everything every engine keeps for profile `ProfileId`: cookies,
/// storage, caches and the stores themselves. An `Ephemeral` profile keeps
/// nothing on disk. A Space's deletion finishes only once its profile's data
/// is erased this way.
public sealed record DeleteProfileData(Guid RequestId, Guid ProfileId, bool Ephemeral) : DataDeletionIntent(RequestId);
