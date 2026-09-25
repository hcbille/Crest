namespace CrestCore.Contracts;

/// What media the page runs at this moment.
public sealed record PageMedia(Guid PageId) : PageRequest<PageMediaState>;
