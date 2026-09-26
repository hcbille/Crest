namespace CrestCore.Contracts;

/// The site data `ClearSiteData` asked about is gone, or could not all be removed.
public sealed record SiteDataCleared(Guid PageId, Guid ClearanceId, bool Cleared) : EnginePresentation;
