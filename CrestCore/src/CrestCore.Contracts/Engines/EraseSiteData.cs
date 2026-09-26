namespace CrestCore.Contracts;

/// Erases the cookies, storage and caches of the site at `Host` that the
/// engine keeps for profile `ProfileId`, without creating a store the profile
/// does not have; an `Ephemeral` one keeps them only while it is open. The
/// binding answers with `DataErased` for `ErasureId`.
public sealed record EraseSiteData(Guid ProfileId, bool Ephemeral, string Host, Guid ErasureId) : EngineCommand;
