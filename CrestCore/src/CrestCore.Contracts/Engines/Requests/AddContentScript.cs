namespace CrestCore.Contracts;

/// Runs `Source` in Crest's own isolated world of every document the page
/// loads from now on, or of its main frame only. Its messages arrive as
/// `ContentMessagePosted`.
public sealed record AddContentScript(Guid PageId, string Source, bool MainFrameOnly) : PageRequest<bool>;
