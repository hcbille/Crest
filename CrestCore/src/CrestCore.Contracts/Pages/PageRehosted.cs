namespace CrestCore.Contracts;

/// A page of a Space moved from engine `From` to engine `To`, for `Reason`,
/// with the address of the site `Origin`, or null for an address that is not
/// a web page's. The `PageChanged` before it carries the page on its new
/// engine.
public sealed record PageRehosted(Guid PageId, Guid SpaceId, SiteOrigin? Origin, EngineKind From, EngineKind To, RehostReason Reason)
    : Change;
