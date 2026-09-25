namespace CrestCore.Contracts;

/// Whether the extension has a side panel for the page's own tab.
public sealed record HasSidePanel(Guid PageId, string ExtensionId) : PageRequest<bool>;
