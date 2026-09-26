namespace CrestCore.Contracts;

/// Allows or blocks `Permission` for the site the page shows, as Crest's record
/// decided, or clears the site's own setting so the engine's default applies.
public sealed record SetSitePermission(Guid PageId, SitePermission Permission, bool? Allowed) : PageRequest<bool>;
