namespace CrestCore.Contracts;

/// Erases the cookies, storage and caches of the site at `Host` that every
/// engine keeps for profile `ProfileId`. An `Ephemeral` profile keeps them
/// only in memory, while it is open.
public sealed record DeleteSiteData(Guid RequestId, Guid ProfileId, bool Ephemeral, string Host) : DataDeletionIntent(RequestId);
