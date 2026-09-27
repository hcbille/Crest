namespace CrestCore.Contracts;

#region Intents

/// Erases everything every engine keeps for profile `ProfileId`: cookies,
/// storage, caches and the stores themselves. An `Ephemeral` profile keeps
/// nothing on disk. A Space's deletion finishes only once its profile's data
/// is erased this way.
public sealed record DeleteProfileData(Guid RequestId, Guid ProfileId, bool Ephemeral) : DataDeletionIntent(RequestId);

/// Erases the cookies, storage and caches of the site at `Host` that every
/// engine keeps for profile `ProfileId`. An `Ephemeral` profile keeps them
/// only in memory, while it is open.
public sealed record DeleteSiteData(Guid RequestId, Guid ProfileId, bool Ephemeral, string Host) : DataDeletionIntent(RequestId);

#endregion

#region Changes

/// A data deletion ended: `Deleted` says every registered engine erased what
/// it was asked to.
public sealed record DataDeleted(Guid RequestId, bool Deleted) : Change;

#endregion

#region Rejections

/// A site data deletion named no host a site can have.
public sealed record InvalidSiteHost : Rejection;

/// A Space's deletion cannot finish before this run erased its profile's data
/// on every registered engine.
public sealed record SpaceDataNotErased(Guid SpaceId) : Rejection;

#endregion
