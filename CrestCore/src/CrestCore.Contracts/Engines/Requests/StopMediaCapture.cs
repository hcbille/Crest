namespace CrestCore.Contracts;

/// Ends the page's live capture from `Permission`'s devices, after Crest
/// withdrew the grant that allowed it. False when the engine ends capture
/// itself once `SetSitePermission` blocks it.
public sealed record StopMediaCapture(Guid PageId, SitePermission Permission) : PageRequest<bool>;
