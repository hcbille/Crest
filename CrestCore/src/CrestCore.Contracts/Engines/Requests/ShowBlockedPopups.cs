namespace CrestCore.Contracts;

/// Opens the pop-ups the engine blocked in the page's document. False when it
/// blocked none.
public sealed record ShowBlockedPopups(Guid PageId) : PageRequest<bool>;
