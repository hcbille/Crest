namespace CrestCore.Contracts;

/// The page's media session is the one Crest shows for `Document`, the
/// identity Crest issued for the document the page shows now.
public sealed record ActivateMediaSession(Guid PageId, string Document) : PageRequest<bool>;
