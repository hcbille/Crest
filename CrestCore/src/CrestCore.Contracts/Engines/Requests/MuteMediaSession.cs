namespace CrestCore.Contracts;

/// Mutes or unmutes the page while its media session is still `Document`'s.
public sealed record MuteMediaSession(Guid PageId, string Document, bool Muted) : PageRequest<bool>;
