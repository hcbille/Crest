namespace CrestCore.Contracts;

/// Removes the cookies, storage and cache of the site the page shows from its
/// profile, and presents `SiteDataCleared` with `ClearanceId`. False when the
/// page shows no web site.
public sealed record ClearSiteData(Guid PageId, Guid ClearanceId) : PageRequest<bool>;
